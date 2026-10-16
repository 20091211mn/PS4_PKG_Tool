// PS4 Split & Merge - SDL2 UI (OpenOrbis). Tabs: Split | Merge | Store (no Send tab)
// File format matches the mobile apps: <file>.part1, .part2 ...
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <errno.h>
#include <dirent.h>
#include <sys/stat.h>
#include <string>
#include <vector>
#include <thread>
#include <mutex>
#include <atomic>
#include <algorithm>
#include <orbis/libkernel.h>
#include <orbis/Sysmodule.h>
#include <SDL2/SDL.h>
#include <proto-include.h>

#include <sstream>
std::stringstream debugLogStream;
#define W 1920
#define H 1080
#define BUFSZ (8*1024*1024)
#define MAXPART 4294967295LL
#define BASEDIR "/data/splitter"

struct Col { uint8_t r, g, b; };
static const Col C_BG   = {16, 18, 28};
static const Col C_BAR  = {26, 30, 46};
static const Col C_ACC  = {0, 140, 255};
static const Col C_SEL  = {38, 52, 88};
static const Col C_TXT  = {235, 238, 245};
static const Col C_DIM  = {140, 148, 168};
static const Col C_OK   = {70, 200, 120};
static const Col C_ERR  = {235, 90, 90};

static FT_Library ftLib;
static FT_Face fBody, fBig, fSmall;
static SDL_Window* window;
static SDL_Renderer* renderer;
static SDL_Surface* surf;

// ---------- logging ----------
static FILE* lg = NULL;
static void LOG(const char* m){ printf("%s\n", m); if(lg){ fprintf(lg,"%s\n",m); fflush(lg);} }

// ---------- drawing ----------
static void fillRect(int x,int y,int w,int h,Col c){
  SDL_SetRenderDrawColor(renderer,c.r,c.g,c.b,255);
  SDL_Rect r={x,y,w,h}; SDL_RenderFillRect(renderer,&r);
}
static int textWidth(FT_Face f,const char* s){
  int w=0;
  for(;*s;s++){ unsigned char ch=(unsigned char)*s; if(ch>126) ch='?';
    if(FT_Load_Char(f,ch,FT_LOAD_DEFAULT)) continue; w+=f->glyph->advance.x>>6; }
  return w;
}
static void drawText(FT_Face f,const char* s,int x,int y,Col c){
  if(!surf || surf->format->BytesPerPixel!=4) return;
  int pen=x; int base=y+(int)f->size->metrics.y_ppem;
  for(;*s;s++){
    unsigned char ch=(unsigned char)*s; if(ch>126) ch='?';
    if(FT_Load_Char(f,ch,FT_LOAD_RENDER)) continue;
    FT_GlyphSlot g=f->glyph;
    for(unsigned yy=0;yy<g->bitmap.rows;yy++){
      for(unsigned xx=0;xx<g->bitmap.width;xx++){
        int a=g->bitmap.buffer[yy*g->bitmap.pitch+xx]; if(!a) continue;
        int px=pen+g->bitmap_left+(int)xx, py=base-g->bitmap_top+(int)yy;
        if(px<0||py<0||px>=surf->w||py>=surf->h) continue;
        uint32_t* p=(uint32_t*)((uint8_t*)surf->pixels+py*surf->pitch)+px;
        uint8_t br,bg,bb; SDL_GetRGB(*p,surf->format,&br,&bg,&bb);
        uint8_t r=(c.r*a+br*(255-a))/255, gg=(c.g*a+bg*(255-a))/255, b=(c.b*a+bb*(255-a))/255;
        *p=SDL_MapRGB(surf->format,r,gg,b);
      }
    }
    pen+=g->advance.x>>6;
  }
}

// ---------- file ops (same rules as the mobile apps) ----------
static std::mutex mtx;
static char statusMsg[256]="Ready";
static Col statusCol=C_DIM;
static std::atomic<int> progress(0);
static std::atomic<bool> busy(false);

static void setStatus(const char* m,Col c){ std::lock_guard<std::mutex> l(mtx); snprintf(statusMsg,sizeof(statusMsg),"%s",m); statusCol=c; LOG(m); }

static long long fsz(FILE* f){ fseeko(f,0,SEEK_END); long long s=ftello(f); fseeko(f,0,SEEK_SET); return s; }
static int copyn(FILE* s,FILE* d,long long len,char* buf,long long* done,long long total){
  while(len>0){
    size_t want=len<BUFSZ?(size_t)len:BUFSZ;
    size_t g=fread(buf,1,want,s); if(g==0) return -1;
    if(fwrite(buf,1,g,d)!=g) return -2;
    len-=g; *done+=g; progress=(int)((*done)*100/(total>0?total:1));
  }
  return 0;
}
static void doSplit(std::string path,int n){
  busy=true; progress=0;
  FILE* f=fopen(path.c_str(),"rb");
  if(!f){ setStatus("Input not found",C_ERR); busy=false; return; }
  long long size=fsz(f);
  if(n<2||n>size){ setStatus("Bad parts count",C_ERR); fclose(f); busy=false; return; }
  long long ps=(size+n-1)/n;
  if(ps>=MAXPART){ setStatus("Part larger than 4GB - increase parts",C_ERR); fclose(f); busy=false; return; }
  char* buf=(char*)malloc(BUFSZ);
  if(!buf){ setStatus("No memory",C_ERR); fclose(f); busy=false; return; }
  long long done=0; time_t t0=time(NULL);
  for(int i=1;i<=n;i++){
    long long len=ps<size-done?ps:size-done; if(len<=0) break;
    char out[700]; snprintf(out,sizeof(out),"%s.part%d",path.c_str(),i);
    char m[128]; snprintf(m,sizeof(m),"Splitting part %d/%d ...",i,n); setStatus(m,C_DIM);
    FILE* o=fopen(out,"wb");
    if(!o){ setStatus("Cannot write part (disk full / read-only?)",C_ERR); free(buf); fclose(f); busy=false; return; }
    long long before=done; (void)before;
    int r=copyn(f,o,len,buf,&done,size); fclose(o);
    if(r){ setStatus("Copy error",C_ERR); free(buf); fclose(f); busy=false; return; }
  }
  free(buf); fclose(f);
  long long secs=(long long)(time(NULL)-t0); if(secs<1) secs=1;
  char m[128]; snprintf(m,sizeof(m),"Split complete (%lld MB/s)",(size/1048576)/secs);
  progress=100; setStatus(m,C_OK); busy=false;
}
static void doMerge(std::string path){
  busy=true; progress=0;
  int cnt=0; long long total=0; char pn[700];
  for(;;){ snprintf(pn,sizeof(pn),"%s.part%d",path.c_str(),cnt+1);
    FILE* f=fopen(pn,"rb"); if(!f) break; total+=fsz(f); fclose(f); cnt++; }
  if(cnt==0){ setStatus("No parts found",C_ERR); busy=false; return; }
  FILE* o=fopen(path.c_str(),"wb");
  if(!o){ setStatus("Cannot write output",C_ERR); busy=false; return; }
  char* buf=(char*)malloc(BUFSZ);
  if(!buf){ setStatus("No memory",C_ERR); fclose(o); busy=false; return; }
  long long done=0; time_t t0=time(NULL);
  for(int i=1;i<=cnt;i++){
    snprintf(pn,sizeof(pn),"%s.part%d",path.c_str(),i);
    char m[128]; snprintf(m,sizeof(m),"Merging part %d/%d ...",i,cnt); setStatus(m,C_DIM);
    FILE* f=fopen(pn,"rb"); if(!f){ setStatus("Missing part",C_ERR); free(buf); fclose(o); busy=false; return; }
    long long len=fsz(f);
    int r=copyn(f,o,len,buf,&done,total); fclose(f);
    if(r){ setStatus("Copy error",C_ERR); free(buf); fclose(o); busy=false; return; }
  }
  free(buf); fclose(o);
  FILE* c=fopen(path.c_str(),"rb"); long long fin=c?fsz(c):-1; if(c) fclose(c);
  if(fin!=total){ setStatus("Final size mismatch",C_ERR); busy=false; return; }
  long long secs=(long long)(time(NULL)-t0); if(secs<1) secs=1;
  char m[128]; snprintf(m,sizeof(m),"Merge complete (%lld MB/s)",(total/1048576)/secs);
  progress=100; setStatus(m,C_OK); busy=false;
}

// ---------- file lists ----------
struct Entry { std::string path; std::string label; long long size; };
static std::vector<Entry> list;
static const char* DIRS[]={BASEDIR,"/mnt/usb0/splitter","/mnt/usb1/splitter"};
static bool endsWith(const std::string& s,const char* suf){ size_t n=strlen(suf); return s.size()>=n && s.compare(s.size()-n,n,suf)==0; }
static bool hasPart(const std::string& n){ return n.find(".part")!=std::string::npos; }

static void refresh(int tab){
  list.clear();
  if(tab==2) return;
  for(auto d:DIRS){
    DIR* dp=opendir(d); if(!dp) continue;
    struct dirent* e;
    while((e=readdir(dp))){
      std::string n=e->d_name; if(n=="."||n==".."||n=="log.txt"||n=="store.txt") continue;
      std::string full=std::string(d)+"/"+n;
      struct stat st; if(stat(full.c_str(),&st)!=0||!S_ISREG(st.st_mode)) continue;
      if(tab==0 && !hasPart(n)) list.push_back({full,n,(long long)st.st_size});
      if(tab==1 && endsWith(n,".part1")){ std::string b=full.substr(0,full.size()-6);
        list.push_back({b,n.substr(0,n.size()-6),(long long)st.st_size}); }
    }
    closedir(dp);
  }
  std::sort(list.begin(),list.end(),[](const Entry&a,const Entry&b){return a.label<b.label;});
}
static std::vector<std::string> storeLines;
static void loadStore(){
  storeLines.clear();
  FILE* f=fopen(BASEDIR "/store.txt","r"); if(!f) return;
  char ln[512]; while(fgets(ln,sizeof(ln),f)){ ln[strcspn(ln,"\r\n")]=0; if(ln[0]) storeLines.push_back(ln); }
  fclose(f);
}
static std::string human(long long b){
  char t[64];
  if(b>=1073741824LL) snprintf(t,sizeof(t),"%.2f GB",b/1073741824.0);
  else if(b>=1048576) snprintf(t,sizeof(t),"%.1f MB",b/1048576.0);
  else snprintf(t,sizeof(t),"%lld KB",b/1024);
  return t;
}

// ---------- UI ----------
static int tab=0, sel=0, scroll=0, parts=2;
static const char* TABS[]={"Split","Merge","Store"};
static std::thread worker;

static void render(){
  fillRect(0,0,W,H,C_BG);
  fillRect(0,0,W,110,C_BAR);
  drawText(fBig,"PS4 Split & Merge",60,22,C_TXT);
  { char t[96]; snprintf(t,sizeof(t),"%s   [L1/R1 tabs]  [X run]  [Triangle refresh]",TABS[tab]); 
    int w=textWidth(fSmall,t); drawText(fSmall,t,W-w-60,40,C_DIM); }

  if(tab<2){
    drawText(fBody,tab==0?"Select a file to split:":"Select a file to merge (needs .part1, .part2 ...):",60,140,C_DIM);
    int rows=12, y0=190;
    if(list.empty()) drawText(fBody,"No files. Put files in /data/splitter (or USB: /splitter)",60,y0,C_DIM);
    if(sel<scroll) scroll=sel; if(sel>=scroll+rows) scroll=sel-rows+1;
    for(int i=0;i<rows && scroll+i<(int)list.size();i++){
      int idx=scroll+i; int y=y0+i*58;
      if(idx==sel) fillRect(50,y-6,1200,52,C_SEL);
      std::string nm=list[idx].label; if(nm.size()>52) nm=nm.substr(0,49)+"...";
      drawText(fBody,nm.c_str(),70,y,idx==sel?C_TXT:C_DIM);
      std::string sz=human(list[idx].size); drawText(fBody,sz.c_str(),1060,y,C_DIM);
    }
    // side panel
    fillRect(1300,150,560,380,C_BAR);
    if(tab==0){
      drawText(fBody,"Number of parts",1330,175,C_DIM);
      char t[32]; snprintf(t,sizeof(t),"< %d >",parts); drawText(fBig,t,1330,215,C_ACC);
      if(!list.empty()){ long long ps=(list[sel].size+parts-1)/parts; std::string s="Each part ~ "+human(ps);
        drawText(fBody,s.c_str(),1330,300,C_DIM);
        if(ps>=MAXPART) drawText(fBody,"Part > 4GB: increase parts",1330,345,C_ERR); }
      drawText(fBody,"[Left/Right] change parts",1330,440,C_DIM);
    } else {
      drawText(fBody,"Joins .part1 .part2 ...",1330,175,C_DIM);
      drawText(fBody,"into the original file",1330,215,C_DIM);
    }
  } else {
    drawText(fBody,"Store",60,140,C_DIM);
    if(storeLines.empty()){
      drawText(fBody,"No items yet.",70,200,C_TXT);
      drawText(fBody,"Add lines  Title|Description  to /data/splitter/store.txt",70,255,C_DIM);
    }
    for(size_t i=0;i<storeLines.size()&&i<12;i++){
      fillRect(50,190+(int)i*70-6,1820,60,(i==(size_t)sel)?C_SEL:C_BAR);
      std::string s=storeLines[i]; std::string a=s,b;
      size_t p=s.find('|'); if(p!=std::string::npos){ a=s.substr(0,p); b=s.substr(p+1); }
      if(a.size()>40) a=a.substr(0,40); if(b.size()>70) b=b.substr(0,70);
      drawText(fBody,a.c_str(),70,190+(int)i*70,C_TXT); drawText(fBody,b.c_str(),700,190+(int)i*70,C_DIM);
    }
  }

  // status + progress
  { std::lock_guard<std::mutex> l(mtx); drawText(fBody,statusMsg,60,900,statusCol); }
  fillRect(60,945,1800,26,C_BAR);
  fillRect(60,945,1800*progress.load()/100,26,C_ACC);

  // tab bar
  fillRect(0,990,W,90,C_BAR);
  for(int i=0;i<3;i++){
    int x=i*640; if(i==tab) fillRect(x,990,640,90,C_SEL), fillRect(x,990,640,6,C_ACC);
    int w=textWidth(fBig,TABS[i]); drawText(fBig,TABS[i],x+(640-w)/2,1008,i==tab?C_TXT:C_DIM);
  }
}

static void startOp(){
  if(busy||tab==2||list.empty()) return;
  if(worker.joinable()) worker.join();
  std::string p=list[sel].path;
  if(tab==0){ int n=parts; worker=std::thread(doSplit,p,n); }
  else worker=std::thread(doMerge,p);
}
static void switchTab(int t){ tab=(t+3)%3; sel=0; scroll=0; if(tab==2) loadStore(); else refresh(tab); }

static void onButton(int b){
  // OpenOrbis SDL joystick mapping
  switch(b){
    case 0: startOp(); break;                       // cross
    case 3: refresh(tab); if(tab==2) loadStore(); break; // triangle
    case 4: switchTab(tab-1); break;                // L1
    case 5: switchTab(tab+1); break;                // R1
    case 13: if(sel>0) sel--; break;                // up
    case 14: { int n=(tab==2)?(int)storeLines.size():(int)list.size(); if(sel+1<n) sel++; } break; // down
    case 15: if(tab==0&&parts>2) parts--; break;    // left
    case 16: if(tab==0&&parts<99) parts++; break;   // right
  }
}

int main(){
  setvbuf(stdout,NULL,_IONBF,0);
  mkdir(BASEDIR,0777);
  lg=fopen(BASEDIR "/log.txt","w");
  LOG("start");
  if(SDL_Init(SDL_INIT_VIDEO|SDL_INIT_JOYSTICK)!=0){ LOG("SDL_Init failed"); for(;;) SDL_Delay(1000); }
  if(sceSysmoduleLoadModule(ORBIS_SYSMODULE_FREETYPE_OL)<0){ LOG("freetype module failed"); for(;;) SDL_Delay(1000); }
  if(FT_Init_FreeType(&ftLib)){ LOG("FT init failed"); for(;;) SDL_Delay(1000); }
  const char* F1="/app0/assets/fonts/VeraMono.ttf"; const char* F2="/app0/assets/fonts/Bebas-Regular.ttf";
  if(FT_New_Face(ftLib,F1,0,&fBody)||FT_New_Face(ftLib,F1,0,&fSmall)||FT_New_Face(ftLib,F2,0,&fBig)){ LOG("font load failed"); for(;;) SDL_Delay(1000); }
  FT_Set_Pixel_Sizes(fBody,0,30); FT_Set_Pixel_Sizes(fSmall,0,24); FT_Set_Pixel_Sizes(fBig,0,56);
  window=SDL_CreateWindow("main",SDL_WINDOWPOS_UNDEFINED,SDL_WINDOWPOS_UNDEFINED,W,H,0);
  if(!window){ LOG("window failed"); for(;;) SDL_Delay(1000); }
  surf=SDL_GetWindowSurface(window);
  renderer=SDL_CreateSoftwareRenderer(surf);
  if(!renderer){ LOG("renderer failed"); for(;;) SDL_Delay(1000); }
  SDL_Joystick* pad=NULL;
  if(SDL_NumJoysticks()>0) pad=SDL_JoystickOpen(0);
  refresh(0);
  for(;;){
    if(!pad && SDL_NumJoysticks()>0) pad=SDL_JoystickOpen(0);
    SDL_Event ev;
    while(SDL_PollEvent(&ev)) if(ev.type==SDL_JOYBUTTONDOWN) onButton(ev.jbutton.button);
    render();
    SDL_UpdateWindowSurface(window);
    SDL_Delay(30);
  }
  return 0;
}
