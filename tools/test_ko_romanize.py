"""Rachel's gate for Korean readings: known sound-change words. Run: python3 -I tools/test_ko_romanize.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ko_romanize import romanize, has_join, choose

# (spelling, pronunciation as NIKL writes it, Revised Romanization)
CASES = [
    ("국물", "궁물", "gungmul"),        # nasalisation
    ("같이", "가치", "gachi"),          # palatalisation
    ("좋다", "조ː타", "jota"),          # aspiration
    ("학교", "학꾜", "hakgyo"),         # tensing not written
    ("신라", "실라", "silla"),          # ㄴㄹ → ll
    ("설날", "설ː랄", "seollal"),
    ("먹다", "먹따", "meokda"),
    ("읽다", "익따", "ikda"),
    ("값", "갑", "gap"),
    ("닭", "닥", "dak"),
    ("독립", "동닙", "dongnip"),
    ("백마", "뱅마", "baengma"),
    ("해돋이", "해도지", "haedoji"),
    ("놓다", "노타", "nota"),
    ("굳이", "구지", "guji"),
    ("종로", "종노", "jongno"),
    ("별내", "별래", "byeollae"),
    ("맛있다", "마싣따", "masitda"),
    ("꽃", "꼳", "kkot"),
    ("끝나다", "끈나다", "kkeunnada"),
    ("국적", "국쩍", "gukjeok"),
    ("김밥", "김ː밥", "gimbap"),
    ("깎다", "깍따", "kkakda"),
    ("앉다", "안따", "anda"),
    ("많다", "만ː타", "manta"),
    ("싫다", "실타", "silta"),
    ("잎", "입", "ip"),
    ("의사", "의사", "uisa"),
    ("한국어", "한ː구거", "hangugeo"),
    ("감사합니다", "감ː사함니다", "gamsahamnida"),
    ("물", "물", "mul"),
    ("라디오", "라디오", "radio"),
    ("야구", "야ː구 ", "yagu"),         # trailing space in the source
    ("이기다", "이기다", "igida"),
]

# Several accepted pronunciations, as NIKL lists them (relaxed variant often first).
CHOOSE = [
    ("계단", ["게단", "계단"], "gyedan"),
    ("시계", ["시게", "시계"], "sigye"),
    ("세계", ["세ː게", "세ː계"], "segye"),
    ("회사", ["회ː사", "훼ː사"], "hoesa"),
    ("거의", ["거의", "거이"], "geoui"),
    ("편의점", ["펴늬점", "펴니점"], "pyeonuijeom"),
    ("맛있다", ["마딛따", "마싣따", "마딘는"], "masitda"),
    ("멋있다", ["머딛따", "머싣따"], "meositda"),
    ("바닷가", ["바다까", "바닫까"], "badatga"),
    ("어젯밤", ["어제빰", "어젣빰"], "eojetbam"),
    ("젓가락", ["저까락", "젇까락"], "jeotgarak"),
    ("햇빛", ["해삗", "핻삗"], "haetbit"),
    ("김밥", ["김ː밥", "김ː빱", "김ː바비"], "gimbap"),
    ("교육", ["교ː육", "교ː유기", "교ː육또"], "gyoyuk"),   # inflected forms ignored
]
for s_, ps, want in CHOOSE:
    got = romanize(s_, choose(s_, ps))
    if got != want:
        print(f"FAIL choose {s_} {ps}: want {want}, got {got}")
        CASES.append((s_, "", "x"))  # counted below

fails = [(s, p, want, romanize(s, p) if p else "") for s, p, want in CASES if not p or romanize(s, p) != want]
for s, p, want, got in fails:
    print(f"FAIL {s} [{p}]: want {want}, got {got}")
assert has_join("인터넷") and not has_join("라디오") and not has_join("물")
if fails:
    sys.exit(f"{len(fails)} of {len(CASES)} romanization cases fail")
print(f"ok: {len(CASES)} romanization cases, {len(CHOOSE)} pronunciation choices")
