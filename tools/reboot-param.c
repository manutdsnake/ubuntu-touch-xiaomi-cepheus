/* rb <arg>: reboot(RESTART2, arg), no libc */
static long sc4(long n,long a,long b,long c,long d){register long x8 __asm__("x8")=n;register long x0 __asm__("x0")=a;register long x1 __asm__("x1")=b;register long x2 __asm__("x2")=c;register long x3 __asm__("x3")=d;__asm__ volatile("svc 0":"+r"(x0):"r"(x8),"r"(x1),"r"(x2),"r"(x3):"memory");return x0;}
void cmain(long *sp){char **argv=(char**)(sp+1);sc4(81,0,0,0,0);/*sync*/sc4(142,0xfee1dead,672274793,0xA1B2C3D4,(long)(sp[0]>1?argv[1]:"recovery"));sc4(93,1,0,0,0);}
__asm__(".global _start\n_start:\n mov x0, sp\n bl cmain\n");
