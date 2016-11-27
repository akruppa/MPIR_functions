#include <stdlib.h>
#include <stdio.h>

void addsub_4(long *, long *, const long *, const long *, size_t);

int main()
{
  long s[4], d[4], a[4] = {1,2,3,4}, b[4] = {4,9,16,25};
  
  addsub_4(s, d, a, b, 4);

  printf("Sum: %ld, %ld, %ld, %ld\n", s[0], s[1], s[2], s[3]);
  printf("Diff: %ld, %ld, %ld, %ld\n", d[0], d[1], d[2], d[3]);

  return(0);
}
