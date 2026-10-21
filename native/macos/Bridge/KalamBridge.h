#pragma once
#include <stddef.h>
typedef void (*OMTPEvent)(int kind, const char *json, void *context);
void *omtp_open(const char *path);
const char *omtp_error(void);
void omtp_close(void *handle);
int omtp_invoke(void *handle, const char *symbol, const char *input, int style, OMTPEvent event, void *context);
