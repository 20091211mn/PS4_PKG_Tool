#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <orbis/libkernel.h>
#include "graphics.h"

#define BASE "/data/splitter"
#define BUFSZ (8*1024*1024)
#define MAXPART 4294967295LL
#define FW 1920
#define FH 1080

static Scene2D* sc = NULL;
static int frameID = 0;
static FILE* lg = NULL;

static char sMode[32] = "STARTING";
static char sFile[128] = "";
static char sPart[96] = "";
static char sSpeed[64] = "";
static char sStatus[160] = "PLEASE WAIT";
static int sPct = 0;
static int sState = 0;

static const char* CH = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ.-_/:%?! ";
static const unsigned char GL[][7] = {
 {0b01110,0b10001,0b10011,0b10101,0b11001,0b10001,0b01110},
 {0b00100,0b01100,0b00100,0b00100,0b00100,0b00100,0b01110},
 {0b01110,0b10001,0b00001,0b00010,0b00100,0b01000,0b11111},
 {0b11110,0b00001,0b00001,0b01110,0b00001,0b00001,0b11110},
 {0b00010,0b00110,0b01010,0b10010,0b11111,0b00010,0b00010},
 {0b11111,0b10000,0b11110,0b00001,0b00001,0b10001,0b01110},
 {0b00110,0b01000,0b10000,0b11110,0b10001,0b10001,0b01110},
 {0b11111,0b00001,0b00010,0b00100,0b01000,0b01000,0b01000},
 {0b01110,0b10001,0b10001,0b01110,0b10001,0b10001,0b01110},
 {0b01110,0b10001,0b10001,0b01111,0b00001,0b00010,0b01100},
 {0b01110,0b10001,0b10001,0b11111,0b10001,0b10001,0b10001},
 {0b11110,0b10001,0b10001,0b11110,0b10001,0b10001,0b11110},
 {0b01110,0b10001,0b10000,0b10000,0b10000,0b10001,0b01110},
 {0b11110,0b10001,0b10001,0b10001,0b10001,0b10001,0b11110},
 {0b11111,0b10000,0b10000,0b11110,0b10000,0b10000,0b11111},
 {0b11111,0b10000,0b10000,0b11110,0b10000,0b10000,0b10000},
 {0b01110,0b10001,0b10000,0b10111,0b10001,0b10001,0b01111},
 {0b10001,0b10001,0b10001,0b11111,0b10001,0b10001,0b10001},
 {0b01110,0b00100,0b00100,0b00100,0b00100,0b00100,0b01110},
 {0b00111,0b00010,0b00010,0b00010,0b00010,0b10010,0b01100},
 {0b10001,0b10010,0b10100,0b11000,0b10100,0b10010,0b10001},
 {0b10000,0b10000,0b10000,0b10000,0b10000,0b10000,0b11111},
 {0b10001,0b11011,0b10101,0b10101,0b10001,0b10001,0b10001},
 {0b10001,0b11001,0b10101,0b10011,0b10001,0b10001,0b10001},
 {0b01110,0b10001,0b10001,0b10001,0b10001,0b10001,0b01110},
 {0b11110,0b10001,0b10001,0b11110,0b10000,0b10000,0b10000},
 {0b01110,0b10001,0b10001,0b10001,0b10101,0b10010,0b01101},
 {0b11110,0b10001,0b10001,0b11110,0b10100,0b10010,0b10001},
 {0b01111,0b10000,0b10000,0b01110,0b00001,0b00001,0b11110},
 {0b11111,0b00100,0b00100,0b00100,0b00100,0b00100,0b00100},
 {0b10001,0b10001,0b10001,0b10001,0b10001,0b10001,0b01110},
 {0b10001,0b10001,0b10001,0b10001,0b10001,0b01010,0b00100},
 {0b10001,0b10001,0b10001,0b10101,0b10101,0b10101,0b01010},
 {0b10001,0b10001,0b01010,0b00100,0b01010,0b10001,0b10001},
 {0b10001,0b10001,0b01010,0b00100,0b00100,0b00100,0b00100},
 {0b11111,0b00001,0b00010,0b00100,0b01000,0b10000,0b11111},
 {0,0,0,0,0,0b01100,0b01100},
 {0,0,0,0b11111,0,0,0},
 {0,0,0,0,0,0,0b11111},
 {0b00001,0b00001,0b00010,0b00100,0b01000,0b10000,0b10000},
 {0,0b01100,0b01100,0,0b01100,0b01100,0},
 {0b11001,0b11010,0b00010,0b00100,0b01000,0b01011,0b10011},
 {0b01110,0b10001,0b00001,0b00010,0b00100,0,0b00100},
 {0b00100,0b00100,0b00100,0b00100,0b00100,0,0b00100},
 {0,0,0,0,0,0,0}
};

static const Color cBG = {14, 18, 40};
static const Color cHDR = {24, 60, 140};
static const Color cWHITE = {235, 240, 255};
static const Color cGREY = {150, 160, 190};
static const Color cGREEN = {60, 200, 110};
static const Color cRED = {230, 70, 70};
static const Color cBLUE = {70, 150, 255};
static const Color cBAR = {40, 48, 80};

static void glyph(int x, int y, int s, char c, Color col) {
  if (c == 0) return;
  if (c >= 'a' && c <= 'z') c -= 32;
  const char* p = strchr(CH, c);
  int i = p ? (int)(p - CH) : 42;
  for (int r = 0; r < 7; r++)
    for (int k = 0; k < 5; k++)
      if (GL[i][r] & (1 << (4 - k))) sc->DrawRectangle(x + k * s, y + r * s, s, s, col);
}

static void text(int x, int y, int s, const char* t, Color col) {
  for (; *t; t++) {
    glyph(x, y, s, *t, col);
    x += 6 * s;
  }
}

static void render() {
  if (!sc) return;
  sc->FrameBufferFill(cBG);
  sc->DrawRectangle(0, 0, FW, 150, cHDR);
  text(80, 46, 8, "PS4 PKG MANAGER", cWHITE);
  text(100, 220, 6, sMode, cBLUE);
  text(100, 320, 4, sFile, cGREY);
  text(100, 380, 4, sPart, cGREY);
  sc->DrawRectangle(100, 480, 1720, 70, cBAR);
  Color pc = sState == 2 ? cRED : (sState == 1 ? cGREEN : cBLUE);
  int w = 1720 * sPct / 100;
  if (w > 0) sc->DrawRectangle(100, 480, w, 70, pc);
  char pb[16];
  snprintf(pb, sizeof(pb), "%d%%", sPct);
  text(100, 590, 8, pb, cWHITE);
  text(100, 700, 5, sSpeed, cGREY);
  text(100, 800, 5, sStatus, sState == 2 ? cRED : (sState == 1 ? cGREEN : cWHITE));
  text(100, 1000, 3, "SEND - SPLIT - MERGE - PKG TOOLS", cGREY);
  sc->SubmitFlip(frameID);
  sc->FrameWait(frameID);
  sc->FrameBufferSwap();
  frameID++;
}

static long long gTotal = 1, gDone = 0, gLastB = 0;
static time_t gLastT = 0;

static void LOGF(const char* m) {
  if (lg) { fprintf(lg, "%s\n", m); fflush(lg); }
}

static void setStatus(int st, const char* m) {
  sState = st;
  snprintf(sStatus, sizeof(sStatus), "%s", m);
  LOGF(m);
  render();
}

static void progress(long long add) {
  gDone += add;
  sPct = (int)(gDone * 100 / gTotal);
  time_t n = time(NULL);
  if (n - gLastT >= 1) {
    long long mb = (gDone - gLastB) / 1048576;
    snprintf(sSpeed, sizeof(sSpeed), "SPEED: %lld MB/S", mb / (long long)(n - gLastT));
    gLastT = n;
    gLastB = gDone;
  }
  render();
}

static long long fsize(FILE* f) {
  fseeko(f, 0, SEEK_END);
  long long s = ftello(f);
  fseeko(f, 0, SEEK_SET);
  return s;
}

static int copyn(FILE* s, FILE* d, long long len, char* buf) {
  while (len > 0) {
    size_t want = len < BUFSZ ? (size_t)len : BUFSZ;
    size_t g = fread(buf, 1, want, s);
    if (g == 0) return -1;
    if (fwrite(buf, 1, g, d) != g) return -2;
    len -= g;
    progress((long long)g);
  }
  return 0;
}

static int doSplit(const char* name, int n) {
  char in[512], out[600], m[160];
  snprintf(in, sizeof(in), "%s/%s", BASE, name);
  FILE* f = fopen(in, "rb");
  if (!f) { setStatus(2, "ERROR: INPUT FILE NOT FOUND"); return -1; }
  long long size = fsize(f);
  if (n < 2 || n > size) { setStatus(2, "ERROR: BAD PARTS COUNT"); fclose(f); return -1; }
  long long ps = (size + n - 1) / n;
  if (ps >= MAXPART) { setStatus(2, "ERROR: PART OVER 4GB - USE MORE PARTS"); fclose(f); return -1; }
  char* buf = (char*)malloc(BUFSZ);
  if (!buf) { setStatus(2, "ERROR: NO MEMORY"); fclose(f); return -1; }
  gTotal = size > 0 ? size : 1; gDone = 0; gLastB = 0; gLastT = time(NULL); sPct = 0;
  long long done = 0;
  for (int i = 1; i <= n; i++) {
    long long len = ps < size - done ? ps : size - done;
    if (len <= 0) break;
    snprintf(sPart, sizeof(sPart), "PART %d OF %d", i, n);
    snprintf(out, sizeof(out), "%s.part%d", in, i);
    FILE* o = fopen(out, "wb");
    if (!o) { setStatus(2, "ERROR: CANNOT WRITE PART"); free(buf); fclose(f); return -2; }
    int r = copyn(f, o, len, buf);
    fclose(o);
    if (r) { setStatus(2, "ERROR: COPY FAILED - DISK FULL?"); free(buf); fclose(f); return -3; }
    done += len;
  }
  free(buf);
  fclose(f);
  sPct = 100;
  snprintf(m, sizeof(m), "SPLIT COMPLETE - %d PARTS", n);
  setStatus(1, m);
  return 0;
}

static int doMerge(const char* name) {
  char in[512], pn[600], m[160];
  snprintf(in, sizeof(in), "%s/%s", BASE, name);
  int cnt = 0;
  long long total = 0;
  for (;;) {
    snprintf(pn, sizeof(pn), "%s.part%d", in, cnt + 1);
    FILE* f = fopen(pn, "rb");
    if (!f) break;
    total += fsize(f);
    fclose(f);
    cnt++;
  }
  if (cnt == 0) { setStatus(2, "ERROR: NO PARTS FOUND"); return -1; }
  FILE* o = fopen(in, "wb");
  if (!o) { setStatus(2, "ERROR: CANNOT WRITE OUTPUT"); return -2; }
  char* buf = (char*)malloc(BUFSZ);
  if (!buf) { setStatus(2, "ERROR: NO MEMORY"); fclose(o); return -2; }
  gTotal = total > 0 ? total : 1; gDone = 0; gLastB = 0; gLastT = time(NULL); sPct = 0;
  for (int i = 1; i <= cnt; i++) {
    snprintf(sPart, sizeof(sPart), "PART %d OF %d", i, cnt);
    snprintf(pn, sizeof(pn), "%s.part%d", in, i);
    FILE* f = fopen(pn, "rb");
    if (!f) { setStatus(2, "ERROR: MISSING PART"); free(buf); fclose(o); return -3; }
    int r = copyn(f, o, fsize(f), buf);
    fclose(f);
    if (r) { setStatus(2, "ERROR: COPY FAILED - DISK FULL?"); free(buf); fclose(o); return -4; }
  }
  free(buf);
  fclose(o);
  FILE* c = fopen(in, "rb");
  long long fin = c ? fsize(c) : -1;
  if (c) fclose(c);
  if (fin != total) { setStatus(2, "ERROR: FINAL SIZE MISMATCH"); return -5; }
  sPct = 100;
  snprintf(m, sizeof(m), "MERGE COMPLETE - %d PARTS", cnt);
  setStatus(1, m);
  return 0;
}

int main() {
  lg = fopen(BASE "/log.txt", "w");
  sc = new Scene2D(FW, FH, 4);
  if (!sc->Init(0xC000000, 2)) {
    LOGF("video init failed");
    // no delete: ~Scene2D is not defined in the sample
    sc = NULL;
  }
  render();
  FILE* j = fopen(BASE "/job.txt", "r");
  if (!j) {
    snprintf(sMode, sizeof(sMode), "NO JOB");
    snprintf(sFile, sizeof(sFile), "CREATE /DATA/SPLITTER/JOB.TXT");
    snprintf(sPart, sizeof(sPart), "3 LINES: SPLIT OR MERGE / FILE NAME / PARTS");
    setStatus(2, "JOB.TXT NOT FOUND");
  } else {
    char mode[32] = "", name[256] = "", np[32] = "";
    fgets(mode, sizeof(mode), j);
    fgets(name, sizeof(name), j);
    fgets(np, sizeof(np), j);
    fclose(j);
    mode[strcspn(mode, "\r\n")] = 0;
    name[strcspn(name, "\r\n")] = 0;
    snprintf(sFile, sizeof(sFile), "FILE: %.56s", name);
    if (!strcmp(mode, "split")) {
      snprintf(sMode, sizeof(sMode), "SPLITTING");
      setStatus(0, "WORKING...");
      doSplit(name, atoi(np));
    } else if (!strcmp(mode, "merge")) {
      snprintf(sMode, sizeof(sMode), "MERGING");
      setStatus(0, "WORKING...");
      doMerge(name);
    } else {
      snprintf(sMode, sizeof(sMode), "BAD JOB");
      setStatus(2, "MODE MUST BE SPLIT OR MERGE");
    }
  }
  if (sc) {
    time_t end = time(NULL) + 120;
    while (time(NULL) < end) render();
  }
  if (lg) fclose(lg);
  return 0;
}
