#include <sys/stat.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <orbis/libkernel.h>

static char BASE[64] = "/data/splitter";
#define BUFSZ (8*1024*1024)
#define MAXPART 4294967295LL
static FILE* lg = NULL;
static void LOG(const char* m){ printf("%s\n", m); if(lg){ fprintf(lg,"%s\n",m); fflush(lg);} }
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
  FILE* f = fopen(in,"rb"); if(!f){ LOG("input not found"); return -1; }
  long long size = fsize(f);
  if(n < 2 || n > size){ LOG("bad parts count"); fclose(f); return -1; }
  long long ps = (size + n - 1) / n;
  if(ps >= MAXPART){ LOG("part larger than 4GB"); fclose(f); return -1; }
  char* buf = (char*)malloc(BUFSZ);
  long long done = 0;
  for(int i=1;i<=n;i++){
    long long len = ps < size-done ? ps : size-done;
    if(len <= 0) break;
    snprintf(out,sizeof(out),"%s.part%d",in,i);
    FILE* o = fopen(out,"wb"); if(!o){ LOG("cannot write part"); free(buf); fclose(f); return -2; }
    int r = copyn(f,o,len,buf); fclose(o);
    if(r){ LOG("copy error"); free(buf); fclose(f); return -3; }
    done += len;
    snprintf(m,sizeof(m),"part %d done",i); LOG(m);
  }
  free(buf); fclose(f); LOG("split complete"); return 0;
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
  if(cnt == 0){ LOG("no parts found"); return -1; }
  FILE* o = fopen(in,"wb"); if(!o){ LOG("cannot write output"); return -2; }
  char* buf = (char*)malloc(BUFSZ);
  for(int i=1;i<=cnt;i++){
    snprintf(pn,sizeof(pn),"%s.part%d",in,i);
    FILE* f = fopen(pn,"rb"); if(!f){ LOG("missing part"); free(buf); fclose(o); return -3; }
    int r = copyn(f,o,fsize(f),buf); fclose(f);
    if(r){ LOG("copy error"); free(buf); fclose(o); return -4; }
    snprintf(m,sizeof(m),"merged part %d",i); LOG(m);
  }
  free(buf); fclose(o);
  FILE* c = fopen(in,"rb"); long long fin = c ? fsize(c) : -1; if(c) fclose(c);
  if(fin != total){ LOG("final size mismatch"); return -5; }
  LOG("merge complete"); return 0;
}
int main(){
  const char* dirs[] = {"/data/splitter","/mnt/usb0/splitter","/mnt/usb1/splitter"};
  FILE* j = NULL; char p[128];
  for(int i=0;i<3 && !j;i++){
    mkdir(dirs[i],0777);
    snprintf(p,sizeof(p),"%s/job.txt",dirs[i]);
    j = fopen(p,"r");
    if(j) strcpy(BASE,dirs[i]);
  }
  snprintf(p,sizeof(p),"%s/log.txt",BASE);
  lg = fopen(p,"w");
  if(!j){ LOG("job.txt not found"); if(lg) fclose(lg); return 1; }
  char mode[32]="", name[256]="", np[32]="";
  fgets(mode,sizeof(mode),j); fgets(name,sizeof(name),j); fgets(np,sizeof(np),j);
  fclose(j);
  mode[strcspn(mode,"\r\n")]=0; name[strcspn(name,"\r\n")]=0;
  if(!strcmp(mode,"split")) doSplit(name, atoi(np));
  else if(!strcmp(mode,"merge")) doMerge(name);
  else LOG("mode must be split or merge");
  if(lg) fclose(lg);
  return 0;
}
