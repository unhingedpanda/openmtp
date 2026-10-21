#include "KalamBridge.h"
#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Kalam owns one process-wide device container and has no callback context parameter.
// Hold the gate for the complete foreign call, including its progress callbacks.
static pthread_mutex_t gate = PTHREAD_MUTEX_INITIALIZER;
static OMTPEvent active_event;
static void *active_context;
static _Thread_local char last_error[1024];
static const char *symbols[] = {"Initialize","FetchDeviceInfo","FetchStorages","MakeDirectory","FileExists","DeleteFile","RenameFile","Walk","UploadFiles","DownloadFiles","Dispose"};
static void forward(int kind, char *packet) {
    if (packet) {
        if (active_event) active_event(kind, packet, active_context);
        // Every packet is allocated with C.CString by the unchanged Go adapter.
        free(packet);
    }
}
static void preprocess(char *packet) { forward(0,packet); }
static void progress(char *packet) { forward(1,packet); }
static void done(char *packet) { forward(2,packet); }
void *omtp_open(const char *path) {
    void *handle = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (!handle) { snprintf(last_error,sizeof(last_error),"%s",dlerror()); return NULL; }
    for (size_t i=0; i<sizeof(symbols)/sizeof(symbols[0]); i++) {
        if (!dlsym(handle,symbols[i])) {
            snprintf(last_error,sizeof(last_error),"Missing Kalam operation: %s",symbols[i]);
            // Even an incompatible Go library may already have running runtime threads.
            // Keep it mapped until process exit, just like a successfully loaded engine.
            return NULL;
        }
    }
    return handle;
}
const char *omtp_error(void) { return last_error; }
void omtp_close(void *handle) {
    // Go's shared-library runtime must remain loaded for the life of the process.
    // dlclose can unload code still referenced by Go runtime threads.
    (void)handle;
}
int omtp_invoke(void *handle, const char *symbol, const char *input, int style, OMTPEvent event, void *context) {
    void *fn = dlsym(handle,symbol);
    if (!fn) return -1;
    pthread_mutex_lock(&gate);
    active_event=event; active_context=context;
    // Exported Go parameters are function-pointer addresses, passed as raw pointer values.
    if (style==0) ((void (*)(void *))fn)((void *)done);
    else if (style==1) ((void (*)(const char *,void *))fn)(input,(void *)done);
    else ((void (*)(const char *,void *,void *,void *))fn)(input,(void *)preprocess,(void *)progress,(void *)done);
    active_event=NULL; active_context=NULL;
    pthread_mutex_unlock(&gate);
    return 0;
}
