#include "gop_wire.h"
#define CHECK(x) do { if (!(x)) return __LINE__; } while (0)
#define MAX_FRAME "NEBOOT-GOP/1 1000 0870\r\n"
#define SAMPLE "NEBOOT-GOP/1 0002 0002\r\n23ff00000102\r\n0a200dffeedd\r\nNEBOOT-GOP/END\r\n"

static bool unchanged(const uint8_t *v, uintptr_t len) {
    for(uintptr_t i=0;i<len;i++) if(v[i]!=77) return false;
    return true;
}
int gop_selftest(void) {
    uint8_t src[]=SAMPLE, max_frame[]=MAX_FRAME;
    uint32_t width=99,height=100;
    uintptr_t total=555;
    uint8_t out[20], bytes[]={0x23,0xff,0,255,0,1,2,255,10,32,13,255,255,238,221,255};
    const uintptr_t n=sizeof(src)-1;
    CHECK(!nelgop_wire_header(src,23,&width,&height,&total));
    CHECK(width==99 && height==100 && total==555);
    CHECK(nelgop_wire_header(src,24,&width,&height,&total));
    CHECK(width==2 && height==2 && total==n);
    CHECK(!nelgop_wire_header(src,24,&width,&width,&total));
    CHECK(!nelgop_wire_header(src,24,&width,&height,0));
    CHECK(nelgop_wire_header(max_frame,24,&width,&height,&total));
    CHECK(width==4096 && height==2160 && total==53088520);
    max_frame[21]='1'; CHECK(!nelgop_wire_header(max_frame,24,&width,&height,&total));
    CHECK(width==4096 && height==2160 && total==53088520);
    for(uintptr_t i=0;i<sizeof(out);i++) out[i]=77;
    CHECK(!nelgop_wire_rgba(src,n,out,15) && unchanged(out,sizeof(out)));
    CHECK(!nelgop_wire_rgba(src,n,0,16));
    for(uintptr_t i=0;i<n;i++) CHECK(!nelgop_wire_rgba(src,i,out,sizeof(out)) && unchanged(out,sizeof(out)));
    CHECK(!nelgop_wire_rgba(src,n+1,out,sizeof(out)) && unchanged(out,sizeof(out)));
    src[37]=' '; CHECK(!nelgop_wire_rgba(src,n,out,sizeof(out)) && unchanged(out,sizeof(out))); src[37]='\n';
    src[49]='Z'; CHECK(!nelgop_wire_rgba(src,n,out,sizeof(out)) && unchanged(out,sizeof(out))); src[49]='d';
    src[n-1]='X'; CHECK(!nelgop_wire_rgba(src,n,out,sizeof(out)) && unchanged(out,sizeof(out))); src[n-1]='\n';
    CHECK(nelgop_wire_rgba(src,n,out,sizeof(out)));
    for(uintptr_t i=0;i<sizeof(bytes);i++) CHECK(out[i]==bytes[i]);
    CHECK(unchanged(out+sizeof(bytes),sizeof(out)-sizeof(bytes)));
    return 0;
}
#ifdef GOP_HOSTED
int main(void) { return gop_selftest(); }
#endif
