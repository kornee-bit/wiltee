import Base

# RVC (RV64GC "C" extension) expander: 16-bit halfword -> 32-bit instruction.
# Reserved and RV32-only encodings return 0; hints expand to harmless base
# instructions (writes to x0), never 0.

# Field helpers
# -------------

# bits [n .. n+width) of x selected by mask m, moved to bit position t
def C.mv(+x: U32, n: Nat, +m: U32, t: Nat) -> U32:
  U32.shln(U32.and(U32.shrn(x, n), m), t)

def C.f(+x: U32, n: Nat, +m: U32) -> U32:
  U32.and(U32.shrn(x, n), m)

# 0 if x == 0, else v
def C.nz(+x: U32, +v: U32) -> U32:
  match x:
    case 0:
      0
    case _:
      v

def C.sx(+v: U32, +m: U32) -> U32:
  U32.sub(U32.xor(v, m), m)

# Encoders (k holds the pre-merged funct3 and opcode)
# -----------------------------------------------------

def C.encI(+imm: U32, +rs1: U32, +rd: U32, +k: U32) -> U32:
  U32.or(
    U32.or(U32.shln(U32.and(imm, 4095), 20n), U32.shln(rs1, 15n)),
    U32.or(U32.shln(rd, 7n), k))

def C.encR(+f7: U32, +rs2: U32, +rs1: U32, +rd: U32, +k: U32) -> U32:
  U32.or(
    U32.or(U32.shln(f7, 25n), U32.shln(rs2, 20n)),
    U32.or(U32.or(U32.shln(rs1, 15n), U32.shln(rd, 7n)), k))

def C.encS(+imm: U32, +rs2: U32, +rs1: U32, +k: U32) -> U32:
  U32.or(
    U32.or(C.mv(imm, 5n, 127, 25n), U32.shln(rs2, 20n)),
    U32.or(U32.or(U32.shln(rs1, 15n), C.mv(imm, 0n, 31, 7n)), k))

def C.encB(+imm: U32, +rs1: U32, +k: U32) -> U32:
  U32.or(
    U32.or(C.mv(imm, 12n, 1, 31n), C.mv(imm, 5n, 63, 25n)),
    U32.or(U32.or(U32.shln(rs1, 15n), C.mv(imm, 1n, 15, 8n)),
      U32.or(C.mv(imm, 11n, 1, 7n), k)))

def C.encJ(+imm: U32) -> U32:
  U32.or(
    U32.or(C.mv(imm, 20n, 1, 31n), C.mv(imm, 1n, 1023, 21n)),
    U32.or(C.mv(imm, 11n, 1, 20n), U32.or(C.mv(imm, 12n, 255, 12n), 111)))

# Registers
# ---------

def C.rd(+h: U32) -> U32:
  C.f(h, 7n, 31)

def C.rs2(+h: U32) -> U32:
  C.f(h, 2n, 31)

# rs1' / rd' (bits 9:7) and rs2' / rd' (bits 4:2), offset by 8
def C.rpa(+h: U32) -> U32:
  U32.add(C.f(h, 7n, 7), 8)

def C.rpb(+h: U32) -> U32:
  U32.add(C.f(h, 2n, 7), 8)

# Immediates (as laid out in the spec, unsigned unless sign-extended)
# -------------------------------------------------------------------

def C.immD(+h: U32) -> U32:
  U32.or(C.mv(h, 10n, 7, 3n), C.mv(h, 5n, 3, 6n))

def C.immW(+h: U32) -> U32:
  U32.or(U32.or(C.mv(h, 10n, 7, 3n), C.mv(h, 6n, 1, 2n)), C.mv(h, 5n, 1, 6n))

def C.imm6(+h: U32) -> U32:
  U32.or(C.mv(h, 12n, 1, 5n), C.mv(h, 2n, 31, 0n))

def C.simm6(+h: U32) -> U32:
  C.sx(C.imm6(h), 32)

def C.immJ(+h: U32) -> U32:
  U32.and(
    C.sx(
      U32.or(
        U32.or(U32.or(C.mv(h, 12n, 1, 11n), C.mv(h, 11n, 1, 4n)),
          U32.or(C.mv(h, 9n, 3, 8n), C.mv(h, 8n, 1, 10n))),
        U32.or(U32.or(C.mv(h, 7n, 1, 6n), C.mv(h, 6n, 1, 7n)),
          U32.or(C.mv(h, 3n, 7, 1n), C.mv(h, 2n, 1, 5n)))),
      2048),
    2097151)

def C.immB(+h: U32) -> U32:
  C.sx(
    U32.or(
      U32.or(C.mv(h, 12n, 1, 8n), C.mv(h, 10n, 3, 3n)),
      U32.or(U32.or(C.mv(h, 5n, 3, 6n), C.mv(h, 3n, 3, 1n)), C.mv(h, 2n, 1, 5n))),
    256)

# Quadrant 0
# ----------

def C.addi4spn(+h: U32) -> U32:
  C.nz(
    C.f(h, 2n, 2047) ,
    C.nz(
      U32.or(
        U32.or(C.mv(h, 7n, 15, 6n), C.mv(h, 11n, 3, 4n)),
        U32.or(C.mv(h, 5n, 1, 3n), C.mv(h, 6n, 1, 2n))),
      C.addi4spn.go(h)))

def C.addi4spn.go(+h: U32) -> U32:
  0
