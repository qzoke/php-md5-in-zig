#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "php.h"
#include "php_ini.h"
#include "ext/standard/info.h"
#include "php_qzoke.h"

/* Declaration of Zig function */
extern char* zig_md5(const char* input, size_t input_len, char* output, size_t output_len);

/* {{{ qzoke_md5(string $data): string */
PHP_FUNCTION(qzoke_md5)
{
    char *input;
    size_t input_len;
    char output[33];

    ZEND_PARSE_PARAMETERS_START(1, 1)
        Z_PARAM_STRING(input, input_len)
    ZEND_PARSE_PARAMETERS_END();

    char *result = zig_md5(input, input_len, output, sizeof(output));

    if (result == NULL) {
        RETURN_FALSE;
    }

    RETURN_STRINGL(output, 32);
}
/* }}} */

/* {{{ arginfo */
ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_qzoke_md5, 0, 1, IS_STRING, 0)
    ZEND_ARG_TYPE_INFO(0, data, IS_STRING, 0)
ZEND_END_ARG_INFO()
/* }}} */

/* {{{ qzoke_functions[] */
static const zend_function_entry qzoke_functions[] = {
    PHP_FE(qzoke_md5, arginfo_qzoke_md5)
    PHP_FE_END
};
/* }}} */

/* {{{ PHP_MINFO_FUNCTION */
PHP_MINFO_FUNCTION(qzoke)
{
    php_info_print_table_start();
    php_info_print_table_header(2, "qzoke support", "enabled");
    php_info_print_table_row(2, "Version", PHP_QZOKE_VERSION);
    php_info_print_table_row(2, "MD5 Implementation", "Zig std.crypto.hash.Md5");
    php_info_print_table_end();
}
/* }}} */

/* {{{ qzoke_module_entry */
zend_module_entry qzoke_module_entry = {
    STANDARD_MODULE_HEADER,
    PHP_QZOKE_EXTNAME,
    qzoke_functions,
    NULL,  /* MINIT */
    NULL,  /* MSHUTDOWN */
    NULL,  /* RINIT */
    NULL,  /* RSHUTDOWN */
    PHP_MINFO(qzoke),
    PHP_QZOKE_VERSION,
    STANDARD_MODULE_PROPERTIES
};
/* }}} */

#ifdef COMPILE_DL_QZOKE
ZEND_GET_MODULE(qzoke)
#endif
