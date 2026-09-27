#ifndef __CMISC__H__
#define __CMISC__H__

#ifdef __cplusplus
extern "C"{
#endif

#include <stdio.h>

#define PI 3.1415926
// 优化：每个参数加括号，整体表达式加括号
#define circle_area(r) (PI * (r) * (r))
#define cx_max(a,b) (((a)>(b)) ? (a) : (b))

#define cx_log(a,b) \
    printf("cx_max(a,b)=%d\n",cx_max(a,b));

#ifdef __cplusplus
}
#endif

#endif __CMISC__H__