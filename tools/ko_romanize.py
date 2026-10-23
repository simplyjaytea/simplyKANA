"""Revised Romanization of Korean, from the pronunciation NIKL lists for a word.

Korean changes sounds where syllables meet (국물 is said 궁물, 같이 가치, 좋다 조타).
Revised Romanization writes those changes, so we start from NIKL's pronunciation,
not the spelling. One exception, from the RR rules themselves: tensing is not
written (학교 is said 학꾜 but romanized hakgyo). So where the pronunciation has
a tense consonant (ㄲ ㄸ ㅃ ㅆ ㅉ) and the spelling has the plain one in the same
place, the plain one is used.

Vowels always come from the spelling (RR writes 계 as gye even when said 게, 의 as
ui), and only the consonants come from the pronunciation.

NIKL often lists more than one accepted pronunciation (게단 and 계단, 마딛따 and
마싣따). choose(spelling, pronunciations) picks the dictionary-form candidate most
faithful to the spelling: keep a final where the spelling has one (바닫까, not
바다까), and prefer carrying a spelled final into the next syllable (마싣따).

romanize(spelling, pronunciation) -> str
"""
INITIALS = ["g", "kk", "n", "d", "tt", "r", "m", "b", "pp", "s", "ss", "", "j", "jj", "ch", "k", "t", "p", "h"]
VOWELS = ["a", "ae", "ya", "yae", "eo", "e", "yeo", "ye", "o", "wa", "wae", "oe", "yo", "u", "wo", "we",
          "wi", "yu", "eu", "ui", "i"]
# Finals by index (0 = none). A pronunciation only has the seven sounded ones, but map all.
FINALS = ["", "k", "k", "k", "n", "n", "n", "t", "l", "k", "m", "l", "l", "l", "p", "l", "m", "p", "p",
          "t", "t", "ng", "t", "t", "k", "t", "p", "t"]
TENSE_TO_PLAIN = {1: 0, 4: 3, 8: 7, 10: 9, 13: 12}  # ㄲ→ㄱ ㄸ→ㄷ ㅃ→ㅂ ㅆ→ㅅ ㅉ→ㅈ
FINAL_RIEUL = 8
INITIAL_RIEUL = 5


def syllables(s):
    out = []
    for ch in s:
        c = ord(ch) - 0xAC00
        if not 0 <= c < 11172:
            raise ValueError(f"not a hangul syllable: {ch!r} in {s!r}")
        out.append((c // 588, (c % 588) // 28, c % 28))
    return out


def clean(pronunciation):
    """NIKL's field: '교ː육', sometimes ':' or a trailing space, or 'a/b' alternatives."""
    p = pronunciation.split("/")[0]
    return "".join(ch for ch in p if ch not in "ː: \t")


def romanize(spelling, pronunciation):
    pron = syllables(clean(pronunciation))
    spell = syllables(spelling.replace(" ", ""))
    if len(spell) != len(pron):
        spell = [None] * len(pron)  # can't align: keep the pronunciation as is
    out, prev_final = [], 0
    for (i, v, f), sp in zip(pron, spell):
        if sp is not None and i in TENSE_TO_PLAIN and sp[0] == TENSE_TO_PLAIN[i]:
            i = sp[0]  # tensing isn't written in RR
        out.append("l" if i == INITIAL_RIEUL and prev_final == FINAL_RIEUL else INITIALS[i])
        out.append(VOWELS[sp[1] if sp is not None else v])  # the spelling's vowel
        out.append(FINALS[f])
        prev_final = f
    return "".join(out)


def has_join(spelling):
    """True if any syllable but the last has a final consonant: a place where sounds can change."""
    return any(f for (_, _, f) in syllables(spelling)[:-1])


# Final consonant index -> the initial it becomes when carried into the next syllable.
FINAL_TO_INITIAL = {1: 0, 2: 1, 4: 2, 7: 3, 8: 5, 16: 6, 17: 7, 19: 9, 20: 10, 22: 12, 23: 14, 24: 15,
                    25: 16, 26: 17, 27: 18}


def choose(spelling, pronunciations):
    """The pronunciation to romanize: among dictionary-form candidates (same number of
    syllables as the word; NIKL also lists inflected forms), the most faithful to the spelling."""
    spell = syllables(spelling.replace(" ", ""))
    cands = []
    for p in pronunciations:
        for alt in p.split("/"):
            c = clean(alt)
            try:
                if c and len(syllables(c)) == len(spell):
                    cands.append(c)
            except ValueError:
                pass
    if not cands:
        return None

    def cost(c):
        score, prev_final = 0, 0
        for (i, v, f), (si, sv, sf) in zip(syllables(c), spell):
            if sf and not f:
                score += 2                       # a spelled final went missing
            carried = si == 11 and FINAL_TO_INITIAL.get(prev_final) in (i, TENSE_TO_PLAIN.get(i))
            if i != si and TENSE_TO_PLAIN.get(i) != si and not carried:
                score += 1                       # initial changed for another reason
            prev_final = sf
        return score

    return min(cands, key=cost)  # ties: the order NIKL lists them
