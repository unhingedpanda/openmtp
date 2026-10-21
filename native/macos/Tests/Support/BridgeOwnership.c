#include "../../Bridge/KalamBridge.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
static char *copied;
static int count;
static void receive(int kind, const char *packet, void *context) {
    if (kind != 2) return;
    free(copied);
    copied=strdup(packet);
    count++;
}
int main(int argc, char **argv) {
    if (argc!=2) return 2;
    void *handle=omtp_open(argv[1]);
    if (!handle) return 3;
    for (int i=0; i<1000; i++) {
        if (omtp_invoke(handle,"Walk","{\"fullPath\":\"/\"}",1,receive,NULL)) return 4;
        if (!copied || !strstr(copied,"旅行📷.jpg")) return 5;
    }
    free(copied); copied=NULL;
    if (count!=1000) return 6;
    puts("1000 callback packets copied and consumed");
    return 0;
}
