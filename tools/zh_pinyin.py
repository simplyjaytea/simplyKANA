"""CC-CEDICT numbered pinyin (ni3 hao3) to tone marks (nǐhǎo), with apostrophes
before a/e/o syllables (nǚ'ér) and erhua r5 written as r (xiàohuàr)."""
import re
TONES={'a':'āáǎà','e':'ēéěè','i':'īíǐì','o':'ōóǒò','u':'ūúǔù','ü':'ǖǘǚǜ'}
def syl(s):
    s=s.replace('u:','ü').replace('v','ü')
    m=re.fullmatch(r"([a-zü]+)([1-5]?)",s,re.I)
    if not m: return s
    base,t=m.group(1),m.group(2)
    if base.lower()=='r' and t in ('5',''): return 'r'
    t=int(t) if t else 5
    if t==5: return base
    low=base.lower()
    for v in ('a','e'):
        if v in low: i=low.index(v); break
    else:
        if 'ou' in low: i=low.index('o')
        else:
            i=max(low.rfind(c) for c in 'aeiouü')
    if i<0: return base
    ch=base[i]; mark=TONES[ch.lower()][t-1]
    if ch.isupper(): mark=mark.upper()
    return base[:i]+mark+base[i+1:]
def marks(numeric):
    out=""
    for k,s in enumerate(numeric.split()):
        p=syl(s)
        if p=='r' and out: out+='r'; continue
        if k and p and p[0].lower() in 'aeoāáǎàēéěèōóǒò': out+="'"
        out+=p
    return out
