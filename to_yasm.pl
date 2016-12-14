#!/usr/bin/env perl

while (<>) {
  # print("< $_");

  s/\bC\b/;/;

  if (/R32/) {
    print;
    next;
  }

  s/mulx\(([^,]+),([^,]+),([^,]+)\)/mulx $1,$2,$3/i;
  s/mulx\(([^,]+),([^,]+),([^,]+),([^,]+)\)/mulx $1$2,$3,$4/i;
  s/ad([co])x\(([^,]+),\(([^,]+)\),([^,]+)\)/ad$1x $2($3),$4/i;
  s/ad([co])x\(([^,]+),([^,]+)\)/ad$1x $2,$3/i;

  s/^dnl/;/;

  s/L\((\w+)\)/.L$1/g;

  $GPR = "(?:[er]?[abcd]x|[abcd][hl]|[er]?[sd]i|[er]?[bsi]p|r[89][dwb]?|r1[0-5][dwb]?)";
  $SSE = "(?:xmm(?:[0-9]|1[0-5]))";
  $AVX = "(?:ymm(?:[0-9]|1[0-5]))";
  $ID = '(?:[[:alpha:]_][[:alnum:]_]*)'; # anything that can be a macro indentifier
  $ADDR = "(?:(?:-?[0-9]+)?\\($ID(?:,\\s*$ID(?:,\\s*[1248])?)?\\))";
  $IMM = '(?:\$?-?[0-9]+)';
  $OP = "(?:$ID|$ADDR|$IMM)";

  my @addresses = ('(a)', '8(a)', '-8(a)', '(a,b)', '8(a,b)', '-8(a,b)', '(a,b,4)', '8(a,b,4)', '-8(a,b,4)');

  foreach my $addr (@addresses) {
   $addr =~ /^$ADDR$/ || die;
   $addr =~ /^$OP$/ || die;
  }

  my @immediates = ('1', '12', '-1', '-12', '$1', '$12', '$-1', '$-12');
  foreach my $imm (@immediates) {
   $imm =~ /^$IMM$/ || die;
   $imm =~ /^$OP$/ || die;
  }

  s/%($GPR)/$1/ig;

  s/^define\(`(\w+)',\s*`(\w+)'\)/%define $1 $2/;
  s/(mov|ad[dc]|ad[co]x|s[ub]b|cmp|lea|and|shr|movsl)q?(\s+)($OP),(\s*)($OP)/$1$2$5,$4$3/;
  #        1    2                    3    4      5    6
  s/mulxq?(\s+)($ID|$ADDR),(\s+)($ID),(\s+)($ID)/mulx$1$6,$3$4,$5$2/;
  
  s/-([0-9]+)\(($ID),\s*($ID),\s*([1248])\)/\[$2 + $3*$4 - $1\]/g;
  s/([0-9]+)\(($ID),\s*($ID),\s*([1248])\)/\[$2 + $3*$4 + $1\]/g;
  s/\(($ID),\s*($ID),\s*([1248])\)/\[$1+$2*$3\]/g;

  s/-([0-9]+)\(($ID),\s*($ID)\)/\[$2 + $3 - $1\]/g;
  s/([0-9]+)\(($ID),\s*($ID)\)/\[$2 + $3 + $1\]/g;
  s/\(($ID),\s*($ID)\)/\[$1+$2\]/g;

  s/-([0-9]+)\(($ID)\)/\[$2 - $1\]/g;
  s/([0-9]+)\(($ID)\)/\[$2 + $1\]/g;
  s/\(($ID)\)/\[$1\]/g;

  s/\$(-?[0-9]+)/$1/;

  s/ALIGN\((\d+)\)/align $1/;
  s/include\(`..\/config.m4'\)/%include 'yasm_mac.inc'/;
  s/PROLOGUE\[(\w+)\]/GLOBAL_FUNC $1/;
  s/ABI_SUPPORT\[\w+\]//;
  s/FUNC_EXIT\(\)//;
  
  
  print;
}
