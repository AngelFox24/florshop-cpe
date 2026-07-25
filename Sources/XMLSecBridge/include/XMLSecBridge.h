#ifndef FLOR_SHOP_XML_SEC_BRIDGE_H
#define FLOR_SHOP_XML_SEC_BRIDGE_H

#include <stddef.h>

int flor_shop_xmlsec_sign_pkcs12(
    const unsigned char *xml,
    size_t xml_size,
    const char *pkcs12_path,
    const char *password,
    const char *signature_id,
    unsigned char **signed_xml,
    size_t *signed_xml_size,
    char **error_message
);

/// Returns 1 when the XMLDSIG signature is valid, 0 when it is invalid, and -1
/// when the XML could not be checked.
int flor_shop_xmlsec_verify(
    const unsigned char *xml,
    size_t xml_size,
    char **error_message
);

void flor_shop_xmlsec_free(void *pointer);

#endif
