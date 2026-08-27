#include "XMLSecBridge.h"

#include <stdlib.h>
#include <string.h>
#include <pthread.h>

#include <libxml/parser.h>
#include <libxml/tree.h>
#include <xmlsec/xmlsec.h>
#include <xmlsec/xmldsig.h>
#include <xmlsec/templates.h>
#include <xmlsec/crypto.h>

static const xmlChar *EXTENSION_NAMESPACE = BAD_CAST "urn:oasis:names:specification:ubl:schema:xsd:CommonExtensionComponents-2";
static pthread_once_t XMLSEC_INITIALIZATION_ONCE = PTHREAD_ONCE_INIT;
static int XMLSEC_INITIALIZATION_SUCCEEDED = 0;

static void initialize_xmlsec(void) {
    xmlInitParser();
    if (xmlSecInit() >= 0 && xmlSecCheckVersion() == 1 &&
        xmlSecCryptoAppInit(NULL) >= 0 && xmlSecCryptoInit() >= 0) {
        XMLSEC_INITIALIZATION_SUCCEEDED = 1;
    }
}

static void set_error(char **error_message, const char *message) {
    if (error_message != NULL) {
        *error_message = strdup(message);
    }
}

static xmlNodePtr find_extension_content(xmlNodePtr node) {
    for (xmlNodePtr current = node; current != NULL; current = current->next) {
        if (current->type == XML_ELEMENT_NODE &&
            xmlStrEqual(current->name, BAD_CAST "ExtensionContent") &&
            current->ns != NULL &&
            xmlStrEqual(current->ns->href, EXTENSION_NAMESPACE)) {
            return current;
        }
        xmlNodePtr child = find_extension_content(current->children);
        if (child != NULL) {
            return child;
        }
    }
    return NULL;
}

static xmlNodePtr find_signature(xmlNodePtr node) {
    for (xmlNodePtr current = node; current != NULL; current = current->next) {
        if (current->type == XML_ELEMENT_NODE &&
            xmlStrEqual(current->name, xmlSecNodeSignature) &&
            current->ns != NULL &&
            xmlStrEqual(current->ns->href, xmlSecDSigNs)) {
            return current;
        }
        xmlNodePtr child = find_signature(current->children);
        if (child != NULL) {
            return child;
        }
    }
    return NULL;
}

static void use_namespace(xmlNodePtr node, xmlNsPtr namespace) {
    for (xmlNodePtr current = node; current != NULL; current = current->next) {
        if (current->type == XML_ELEMENT_NODE) {
            current->ns = namespace;
        }
        use_namespace(current->children, namespace);
    }
}

void flor_shop_xmlsec_free(void *pointer) {
    free(pointer);
}
//MARK: SING
int flor_shop_xmlsec_sign_pkcs12(
    const unsigned char *xml,
    size_t xml_size,
    const char *pkcs12_path,
    const char *password,
    const char *signature_id,
    unsigned char **signed_xml,
    size_t *signed_xml_size,
    char **error_message
) {
    xmlDocPtr document = NULL;
    xmlSecDSigCtxPtr signature_context = NULL;
    xmlSecKeyPtr signing_key = NULL;
    xmlNodePtr extension_content = NULL;
    xmlNodePtr signature = NULL;
    xmlNodePtr reference = NULL;
    xmlNodePtr key_info = NULL;
    xmlNodePtr x509_data = NULL;
    xmlNsPtr ds_namespace = NULL;
    xmlChar *serialized = NULL;
    int serialized_size = 0;
    int result = -1;

    if (signed_xml == NULL || signed_xml_size == NULL || error_message == NULL) {
        return -1;
    }
    *signed_xml = NULL;
    *signed_xml_size = 0;
    *error_message = NULL;

    pthread_once(&XMLSEC_INITIALIZATION_ONCE, initialize_xmlsec);
    if (XMLSEC_INITIALIZATION_SUCCEEDED == 0) {
        set_error(error_message, "No se pudo inicializar libxmlsec.");
        goto cleanup;
    }

    document = xmlReadMemory((const char *)xml, (int)xml_size, NULL, "UTF-8", XML_PARSE_NONET);
    if (document == NULL) {
        set_error(error_message, "El XML base no es válido.");
        goto cleanup;
    }

    extension_content = find_extension_content(xmlDocGetRootElement(document));
    if (extension_content == NULL) {
        set_error(error_message, "No se encontró ext:ExtensionContent en el XML UBL.");
        goto cleanup;
    }
    ds_namespace = xmlSearchNs(document, xmlDocGetRootElement(document), BAD_CAST "ds");
    if (ds_namespace == NULL || !xmlStrEqual(ds_namespace->href, xmlSecDSigNs)) {
        set_error(error_message, "No se encontró el namespace ds requerido por XMLDSIG.");
        goto cleanup;
    }

    signature = xmlSecTmplSignatureCreate(
        document,
        xmlSecTransformInclC14NId,
        xmlSecTransformRsaSha1Id,
        NULL
    );
    if (signature == NULL) {
        set_error(error_message, "No se pudo crear la plantilla XMLDSIG.");
        goto cleanup;
    }
    xmlAddChild(extension_content, signature);
    use_namespace(signature, ds_namespace);
    if (signature->nsDef != NULL) {
        xmlNsPtr local_namespace = signature->nsDef;
        signature->nsDef = NULL;
        xmlFreeNsList(local_namespace);
    }
    xmlSetProp(signature, BAD_CAST "Id", BAD_CAST signature_id);
    reference = xmlSecTmplSignatureAddReference(signature, xmlSecTransformSha1Id, NULL, BAD_CAST "", NULL);
    key_info = xmlSecTmplSignatureEnsureKeyInfo(signature, NULL);
    x509_data = key_info != NULL ? xmlSecTmplKeyInfoAddX509Data(key_info) : NULL;
    if (reference == NULL ||
        xmlSecTmplReferenceAddTransform(reference, xmlSecTransformEnvelopedId) == NULL ||
        key_info == NULL ||
        x509_data == NULL ||
        xmlSecTmplX509DataAddSubjectName(x509_data) == NULL ||
        xmlSecTmplX509DataAddCertificate(x509_data) == NULL) {
        set_error(error_message, "No se pudo configurar la plantilla XMLDSIG.");
        goto cleanup;
    }
    signing_key = xmlSecCryptoAppPkcs12Load(pkcs12_path, password, NULL, NULL);
    if (signing_key == NULL) {
        set_error(error_message, "No se pudo cargar el certificado PKCS#12 o su contraseña es incorrecta.");
        goto cleanup;
    }

    signature_context = xmlSecDSigCtxCreate(NULL);
    if (signature_context == NULL) {
        set_error(error_message, "No se pudo crear el contexto de firma XMLDSIG.");
        goto cleanup;
    }
    signature_context->signKey = signing_key;
    signing_key = NULL;
    if (xmlSecDSigCtxSign(signature_context, signature) < 0) {
        set_error(error_message, "libxmlsec no pudo firmar el XML.");
        goto cleanup;
    }

    xmlDocDumpFormatMemoryEnc(document, &serialized, &serialized_size, "UTF-8", 1);
    if (serialized == NULL || serialized_size <= 0) {
        set_error(error_message, "No se pudo serializar el XML firmado.");
        goto cleanup;
    }

    *signed_xml = (unsigned char *)malloc((size_t)serialized_size);
    if (*signed_xml == NULL) {
        set_error(error_message, "No se pudo reservar memoria para el XML firmado.");
        goto cleanup;
    }
    memcpy(*signed_xml, serialized, (size_t)serialized_size);
    *signed_xml_size = (size_t)serialized_size;
    result = 0;

cleanup:
    if (result != 0 && *signed_xml != NULL) {
        free(*signed_xml);
        *signed_xml = NULL;
        *signed_xml_size = 0;
    }
    if (serialized != NULL) {
        xmlFree(serialized);
    }
    if (signature_context != NULL) {
        xmlSecDSigCtxDestroy(signature_context);
    }
    if (signing_key != NULL) {
        xmlSecKeyDestroy(signing_key);
    }
    if (document != NULL) {
        xmlFreeDoc(document);
    }
    return result;
}
//MARK: VERIFY
int flor_shop_xmlsec_verify(
    const unsigned char *xml,
    size_t xml_size,
    char **error_message
) {
    xmlDocPtr document = NULL;
    xmlNodePtr signature = NULL;
    xmlSecKeysMngrPtr keys_manager = NULL;
    xmlSecDSigCtxPtr signature_context = NULL;
    int result = -1;

    if (error_message == NULL) {
        return -1;
    }
    *error_message = NULL;

    pthread_once(&XMLSEC_INITIALIZATION_ONCE, initialize_xmlsec);
    if (XMLSEC_INITIALIZATION_SUCCEEDED == 0) {
        set_error(error_message, "No se pudo inicializar libxmlsec.");
        goto cleanup;
    }

    document = xmlReadMemory((const char *)xml, (int)xml_size, NULL, "UTF-8", XML_PARSE_NONET);
    if (document == NULL) {
        set_error(error_message, "El XML firmado no es válido.");
        goto cleanup;
    }

    signature = find_signature(xmlDocGetRootElement(document));
    if (signature == NULL) {
        set_error(error_message, "No se encontró ds:Signature en el XML.");
        goto cleanup;
    }

    keys_manager = xmlSecKeysMngrCreate();
    if (keys_manager == NULL || xmlSecCryptoAppDefaultKeysMngrInit(keys_manager) < 0) {
        set_error(error_message, "No se pudo preparar el administrador de claves XMLDSIG.");
        goto cleanup;
    }

    signature_context = xmlSecDSigCtxCreate(keys_manager);
    if (signature_context == NULL) {
        set_error(error_message, "No se pudo crear el contexto de verificación XMLDSIG.");
        goto cleanup;
    }
    // This verifier checks XML integrity using the certificate embedded in
    // ds:KeyInfo. Certificate-chain trust is a separate concern from checking
    // whether this XML was changed after signing.
    signature_context->keyInfoReadCtx.flags |= XMLSEC_KEYINFO_FLAGS_X509DATA_DONT_VERIFY_CERTS;
    if (xmlSecDSigCtxVerify(signature_context, signature) < 0) {
        set_error(error_message, "libxmlsec no pudo verificar el XML.");
        goto cleanup;
    }

    result = signature_context->status == xmlSecDSigStatusSucceeded ? 1 : 0;

cleanup:
    if (signature_context != NULL) {
        xmlSecDSigCtxDestroy(signature_context);
    }
    if (keys_manager != NULL) {
        xmlSecKeysMngrDestroy(keys_manager);
    }
    if (document != NULL) {
        xmlFreeDoc(document);
    }
    return result;
}
