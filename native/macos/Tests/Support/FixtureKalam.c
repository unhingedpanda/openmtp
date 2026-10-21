#include <stdlib.h>
#include <string.h>
#include <unistd.h>
typedef void (*CB)(char *);
static void send(CB cb, const char *s) { if (cb) cb(strdup(s)); }
void Initialize(CB cb) { send(cb,"{\"error\":\"\",\"errorType\":\"\",\"data\":{\"mtpDeviceInfo\":{\"Manufacturer\":\"Fixture\",\"Model\":\"Fixture Phone\"},\"usbDeviceInfo\":{}}}"); }
void FetchDeviceInfo(CB cb) { Initialize(cb); }
void FetchStorages(CB cb) { send(cb,"{\"error\":\"\",\"errorType\":\"\",\"data\":[{\"Sid\":7,\"Info\":{\"StorageDescription\":\"Internal storage\"}}]}"); }
void Walk(char *input, CB cb) {
    if (strstr(input,"broken")) { send(cb,"not json"); return; }
    if (strstr(input,"denied")) { send(cb,"{\"error\":\"Access denied\",\"errorType\":\"ErrorFilePermission\",\"data\":null}"); return; }
    send(cb,"{\"error\":\"\",\"errorType\":\"\",\"data\":[{\"size\":9007199254740993,\"isFolder\":false,\"dateAdded\":\"2026-01-01T00:00:00Z\",\"name\":\"旅行📷.jpg\",\"path\":\"/旅行📷.jpg\",\"parentPath\":\"/\",\"extension\":\"jpg\",\"parentId\":0,\"objectId\":42}]}");
    if (strstr(input,"delayed-return")) usleep(100000);
}
static void yes(CB cb) { send(cb,"{\"error\":\"\",\"errorType\":\"\",\"data\":true}"); }
void Dispose(CB cb) { yes(cb); }
void MakeDirectory(char *s, CB cb) { yes(cb); }
void FileExists(char *s, CB cb) { send(cb,"{\"error\":\"\",\"errorType\":\"\",\"data\":[]}"); }
void DeleteFile(char *s, CB cb) { yes(cb); }
void RenameFile(char *s, CB cb) { yes(cb); }
void UploadFiles(char *s, CB a, CB b, CB c) { yes(c); }
void DownloadFiles(char *s, CB a, CB b, CB c) { yes(c); }
