#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/stat.h>
#include <orbis/libkernel.h>

#define USE_NOTIFY 1
#define BASE "/data/splitter"
#define BUFSZ (8*1024*1024)
#define MAXPART 4294967295LL

#if USE_NOTIFY
typedef struct {
  int type, req_id, priority, msg_id, target_id, user_id, unk1, unk2, app_id, error_num, unk3;
  char use_icon_image_uri;
  char message[1024];
  char uri[1024];
  char unkstr[1024];
} NotifyReq;
#ifdef __cplusplus
extern "C" {
#endif
int ps4_notify_send(int device, void* req, size_t size, int blocking) __asm__("sceKernelSendNotificationRequest");
#ifdef __cplusplus
}
#endif
static void NOTE(const char* m){
  NotifyReq r; memset(&r, 0, sizeof(r));
  r.use_icon_image_uri = 1; r.target_id = -1;
  snprintf(r.uri, sizeof(r.uri), "cxml://psnotification/tex_icon_system");
  snprintf(r.message, sizeof(r.message), "%s", m);
  ps4_notify_send(0, &r, sizeof(r), 0);
}
#else
static void NOTE(const char* m){ (void)m; }
#endif

static FILE* lg = NULL;
static void LOG(const char* m){ printf("%s\n", m); if(lg){ fprintf(lg,"%s\n",m); fflush(lg);} }
static void LOGN(const char* m){ LOG(m); NOTE(m); }
static long long fsize(FILE* f){ fseeko(f,0,SEEK_END); long long s=ftello(f); fseeko(f,0,SEEK_SET); return s; }
static int copyn(FILE* s, FILE* d, long long len, char* buf){
  while(len > 0){
    size_t want = len < BUFSZ ? (size_t)len : BUFSZ;
    size_t g = fread(buf,1,want,s);
    if(g == 0) return -1;
    if(fwrite(buf,1,g,d) != g) return -2;
    len -= g;
  }
  return 0;
}
static int doSplit(const char* name, int n){
  char in[512], out[600], m[256];
  snprintf(in,sizeof(in),"%s/%s",BASE,name);
  FILE* f = fopen(in,"rb"); if(!f){ LOGN("input not found"); return -1; }
  long long size = fsize(f);
  if(n < 2 || n > size){ LOGN("bad parts count"); fclose(f); return -1; }
  long long ps = (size + n - 1) / n;
  if(ps >= MAXPART){ LOGN("part larger than 4GB, increase parts"); fclose(f); return -1; }
  char* buf = (char*)malloc(BUFSZ);
  if(!buf){ LOGN("no memory"); fclose(f); return -1; }
  long long done = 0;
  time_t t0 = time(NULL);
  NOTE("Split started");
  for(int i=1;i<=n;i++){
    long long len = ps < size-done ? ps : size-done;
    if(len <= 0) break;
    snprintf(out,sizeof(out),"%s.part%d",in,i);
    FILE* o = fopen(out,"wb"); if(!o){ LOGN("cannot write part"); free(buf); fclose(f); return -2; }
    int r = copyn(f,o,len,buf); fclose(o);
    if(r){ LOGN("copy error"); free(buf); fclose(f); return -3; }
    done += len;
    snprintf(m,sizeof(m),"part %d/%d done (%d%%)",i,n,(int)(done*100/size)); LOGN(m);
  }
  free(buf); fclose(f);
  long long secs = (long long)(time(NULL)-t0); if(secs < 1) secs = 1;
  snprintf(m,sizeof(m),"split complete: %lld MB/s",(size/1048576)/secs); LOGN(m);
  return 0;
}
static int doMerge(const char* name){
  char in[512], pn[600], m[256];
  snprintf(in,sizeof(in),"%s/%s",BASE,name);
  int cnt = 0; long long total = 0;
  for(;;){
    snprintf(pn,sizeof(pn),"%s.part%d",in,cnt+1);
    FILE* f = fopen(pn,"rb"); if(!f) break;
    total += fsize(f); fclose(f); cnt++;
  }
  if(cnt == 0){ LOGN("no parts found"); return -1; }
  FILE* o = fopen(in,"wb"); if(!o){ LOGN("cannot write output"); return -2; }
  char* buf = (char*)malloc(BUFSZ);
  if(!buf){ LOGN("no memory"); fclose(o); return -2; }
  long long done = 0;
  time_t t0 = time(NULL);
  NOTE("Merge started");
  for(int i=1;i<=cnt;i++){
    snprintf(pn,sizeof(pn),"%s.part%d",in,i);
    FILE* f = fopen(pn,"rb"); if(!f){ LOGN("missing part"); free(buf); fclose(o); return -3; }
    long long len = fsize(f);
    int r = copyn(f,o,len,buf); fclose(f);
    if(r){ LOGN("copy error"); free(buf); fclose(o); return -4; }
    done += len;
    snprintf(m,sizeof(m),"merged part %d/%d (%d%%)",i,cnt,(int)(done*100/total)); LOGN(m);
  }
  free(buf); fclose(o);
  FILE* c = fopen(in,"rb"); long long fin = c ? fsize(c) : -1; if(c) fclose(c);
  if(fin != total){ LOGN("final size mismatch"); return -5; }
  long long secs = (long long)(time(NULL)-t0); if(secs < 1) secs = 1;
  snprintf(m,sizeof(m),"merge complete: %lld MB/s",(total/1048576)/secs); LOGN(m);
  return 0;
}
int main(){
  mkdir(BASE, 0777);
  lg = fopen(BASE "/log.txt","w");
  FILE* j = fopen(BASE "/job.txt","r");
  if(!j){ LOGN("job.txt not found in /data/splitter"); if(lg) fclose(lg); return 1; }
  char mode[32]="", name[256]="", np[32]="";
  fgets(mode,sizeof(mode),j); fgets(name,sizeof(name),j); fgets(np,sizeof(np),j);
  fclose(j);
  mode[strcspn(mode,"\r\n")]=0; name[strcspn(name,"\r\n")]=0;
  if(!strcmp(mode,"split")) doSplit(name, atoi(np));
  else if(!strcmp(mode,"merge")) doMerge(name);
  else LOGN("mode must be split or merge");
  if(lg) fclose(lg);
  return 0;
}
