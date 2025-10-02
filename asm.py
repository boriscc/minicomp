import argparse
import dataclasses
import pathlib
import pydantic
import re
import sys
from typing import Self, ClassVar, Literal

class Settings(pydantic.BaseModel):
    model_config = pydantic.ConfigDict(extra="forbid")

    include_comments: bool = True
    include_indent: bool = True
    include_reg_subname: bool = True
    asm_style: Literal["c", "asm"] = "c"

@dataclasses.dataclass
class Token:
    rest: str

@dataclasses.dataclass
class LineIndent(Token):
    count: int

    @classmethod
    def from_text(cls, text: str) -> Self | None:
        parts = re.match(r"^( *)(.*)$", text)
        if not parts:
            return None
        return cls(count=len(parts[1]), rest=parts[2])

    def to_asm(self, settings: Settings) -> str:
        if settings.include_indent:
            return " " * self.count
        return ""

@dataclasses.dataclass
class LineComment(Token):
    comment: str

    @classmethod
    def from_text(cls, text: str) -> Self | None:
        if not text.strip():
            return cls(comment="", rest="")
        parts = re.match(r"^ *#.*$", text)
        if not parts:
            return None
        return cls(comment=parts[0].rstrip(), rest="")

    def to_asm(self, settings: Settings) -> str:
        if settings.include_comments and self.comment:
            return self.comment
        return ""

@dataclasses.dataclass
class Reg:
    idx: int
    subname: str | None
    _name_map = {"ra": 0, "rb": 1, "rc": 2, "rd": 3}
    _idx_map = {v: k for k, v in _name_map.items()}

    @classmethod
    def from_value(cls, value: str) -> Self | None:
        idx = cls._name_map.get(value[:2].lower())
        if idx is None:
            return None
        if len(value) > 2 and value[2] != "-":
            return None
        return cls(idx=idx, subname=value[3:] if len(value) > 2 else None)

    def to_asm(self, settings: Settings) -> str:
        ret = self._idx_map[self.idx]
        if self.subname and settings.include_reg_subname:
            ret += f"-{self.subname}"
        return ret

@dataclasses.dataclass
class RegP(Reg):
    @classmethod
    def from_value(cls, value: str) -> Self | None:
        if not value or value[0] != "*":
            return None
        return super().from_value(value[1:])

    @classmethod
    def from_reg(cls, reg: Reg) -> Self:
        return cls(idx=reg.idx, subname=reg.subname)

    def to_asm(self, settings: Settings) -> str:
        if settings.asm_style == "c":
            return f"*{super().to_asm(settings)}"
        elif settings.asm_style == "asm":
            return super().to_asm(settings)
        else:
            raise NotImplementedError

@dataclasses.dataclass
class RegT(Reg):
    prefix: str = "~"

    @classmethod
    def from_value(cls, value: str) -> Self | None:
        if not value or value[0] not in "~!":
            return None
        ret = super().from_value(value[1:])
        ret.prefix = value[0]
        return ret

    @classmethod
    def from_reg(cls, reg: Reg) -> Self:
        return cls(idx=reg.idx, subname=reg.subname)

    def to_asm(self, settings: Settings) -> str:
        if settings.asm_style == "c":
            return f"{self.prefix}{super().to_asm(settings)}"
        elif settings.asm_style == "asm":
            return super().to_asm(settings)
        else:
            raise NotImplementedError

@dataclasses.dataclass
class Number:
    value: int | str
    text: str

    @classmethod
    def from_value(cls, value: str) -> Self | None:
        value_int: int | str | None = None
        if value.startswith("'"):
            if value == r"'\''":
                value_int = ord("'")
            elif len(value) == 3 and value[2] == "'":
                value_int = ord(value[1])
        elif value.lower().startswith("0x"):
            value_int = int(value[2:], 16)
        elif value.lower().startswith("0b"):
            value_int = int(value[2:], 2)
        elif len(value) == 8 and all(x in "01" for x in value):
            value_int = int(value, 2)
        elif value.startswith("$"):
            value_int = value[1:]
        else:
            try:
                value_int = int(value)
            except ValueError:
                pass
        if value_int is None:
            return None
        return cls(value=value_int, text=value)

    def to_asm(self, settings: Settings) -> str:
        return self.text

    def to_int(self, label_pos: dict[str, int]) -> int:
        if isinstance(self.value, int):
            if self.value >= 256:
                raise ValueError(f"Numerical value {self.value=} >= 256")
            return self.value
        if self.value not in label_pos:
            raise ValueError(f"Missing label {self.value}")
        return label_pos[self.value]

@dataclasses.dataclass
class Values:
    raws: list[str]
    regs: list[Reg | None]
    regps: list[RegP | None]
    regts: list[RegP | None]
    numbers: list[Number | None]
    rest: str
    REG: int = 0
    NUM: int = 1
    REGP: int = 2
    REGT: int = 3

    def match(self, query: list[str | int]) -> bool:
        if len(self.raws) != len(query):
            return False
        correct = []
        query_fixed = []
        for idx in range(len(self.raws)):
            if self.regs[idx] is not None:
                correct.append(self.REG)
            elif self.regps[idx] is not None:
                correct.append(self.REGP)
            elif self.regts[idx] is not None:
                correct.append(self.REGT)
            elif self.numbers[idx] is not None:
                correct.append(self.NUM)
            else:
                correct.append(self.raws[idx].lower())
            if isinstance(query[idx], str):
                query_fixed.append(query[idx].lower())
            else:
                query_fixed.append(query[idx])
        return correct == query_fixed

    @classmethod
    def from_text(cls, text: str) -> Self:
        raws = []
        cur = ""
        cur_space = ""
        idx = 0
        rest = ""
        while idx < len(text):
            if text[idx] in " \t":
                cur_space += text[idx]
                if cur:
                    raws.append(cur)
                    cur = ""
            elif text[idx] == "#" and not cur:
                rest = cur_space + text[idx:]
                break
            elif text[idx] == "'" and not cur:
                if text[idx:idx+4] == r"'\''":
                    raws.append(r"'\''")
                    idx += 3
                elif text[idx + 2] == "'":
                    raws.append(text[idx:idx+3])
                    idx += 2
                else:
                    raise ValueError("Invalid value")
            else:
                cur_space = ""
                cur += text[idx]
            idx += 1
        if cur:
            raws.append(cur)
        return cls(raws=raws, regs=[Reg.from_value(v) for v in raws],
                regps=[RegP.from_value(v) for v in raws],
                regts=[RegT.from_value(v) for v in raws],
                numbers=[Number.from_value(v) for v in raws], rest=rest)

class Content(Token):
    def to_asm(self, settings: Settings) -> str:
        raise NotImplementedError

    def get_ram_size(self, ram_pos: int) -> int:
        return 1

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        raise NotImplementedError

@dataclasses.dataclass
class CData(Content):
    reg: Reg
    num: Number
    format_orig: str

    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match(["data", Values.REG, Values.NUM]):
            return cls(reg=values.regs[1], num=values.numbers[2], format_orig="asm", rest=values.rest)
        if values.match([Values.REG, "=", Values.NUM]):
            return cls(reg=values.regs[0], num=values.numbers[2], format_orig="c", rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        if settings.asm_style == "c":
            return f"{self.reg.to_asm(settings)} = {self.num.to_asm(settings)}"
        elif settings.asm_style == "asm":
            return f"data {self.reg.to_asm(settings)} {self.num.to_asm(settings)}"
        else:
            raise NotImplementedError

    def get_ram_size(self, ram_pos: int) -> int:
        return 2

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        return ram + bytes([(2 << 4) + self.reg.idx, self.num.to_int(label_pos)])

@dataclasses.dataclass
class CEmpty(Content):
    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match([]):
            return cls(rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        return ""

    def get_ram_size(self, ram_pos: int) -> int:
        return 0

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        return ram

@dataclasses.dataclass
class CRamSet(Content):
    num: Number

    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match([".", Values.NUM]):
            return cls(num=values.numbers[1], rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        return f". {self.num.to_asm(settings)}"

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        return ram + bytes([self.num.to_int(label_pos)])

@dataclasses.dataclass
class CLabel(Content):
    name: str
    offset: int

    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if len(values.raws) == 1 and values.raws[0].endswith(":") and not values.raws[0].startswith(":"):
            offset = int(values.raws[0][-2] == ":")
            return cls(name=values.raws[0][:-1-offset], offset=offset, rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        return f"{self.name}{':' * (self.offset + 1)}"

    def get_ram_size(self, ram_pos: int) -> int:
        return 0

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        return ram

@dataclasses.dataclass
class CPragmaSetPos(Content):
    pos: int

    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match(["pragma", "setpos", Values.NUM]) and isinstance(values.numbers[2].value, int):
            return cls(pos=values.numbers[2].value, rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        return f"pragma setpos {self.pos}"

    def get_ram_size(self, ram_pos: int) -> int:
        if ram_pos > self.pos:
            raise ValueError(f"pragma setpos: {self.pos=} > {ram_pos=}")
        return self.pos - ram_pos

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        return ram + bytes(self.pos - len(ram))

@dataclasses.dataclass
class CPragmaPos(Content):
    pos: int

    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match(["pragma", "pos", Values.NUM]) and isinstance(values.numbers[2].value, int):
            return cls(pos=values.numbers[2].value, rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        return f"pragma pos {self.pos}"

    def get_ram_size(self, ram_pos: int) -> int:
        return 0

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        if len(ram) != self.pos:
            raise ValueError(f"Expected {len(ram)=} to equal {self.pos=}")
        return ram

@dataclasses.dataclass
class CPragmaPrintPos(Content):
    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match(["pragma", "printpos"]):
            return cls(rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        return "pragma printpos"

    def get_ram_size(self, ram_pos: int) -> int:
        return 0

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        print(f"Current ram pos: {len(ram)=}")
        return ram

@dataclasses.dataclass
class COutData(Content):
    reg: Reg

    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match(["outd", Values.REG]):
            return cls(reg=values.regs[1], rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        return f"outd {self.reg.to_asm(settings)}"

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        return ram + bytes([(7 << 4) + (2 << 2) + self.reg.idx])

@dataclasses.dataclass
class CInData(Content):
    reg: Reg

    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match(["ind", Values.REG]):
            return cls(reg=values.regs[1], rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        return f"ind {self.reg.to_asm(settings)}"

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        return ram + bytes([(7 << 4) + (0 << 2) + self.reg.idx])

@dataclasses.dataclass
class COutAddress(Content):
    reg: Reg

    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match(["outa", Values.REG]):
            return cls(reg=values.regs[1], rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        return f"outa {self.reg.to_asm(settings)}"

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        return ram + bytes([(7 << 4) + (3 << 2) + self.reg.idx])

@dataclasses.dataclass
class CInAddress(Content):
    reg: Reg

    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match(["ina", Values.REG]):
            return cls(reg=values.regs[1], rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        return f"ina {self.reg.to_asm(settings)}"

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        return ram + bytes([(7 << 4) + (1 << 2) + self.reg.idx])

@dataclasses.dataclass
class CJump(Content):
    num: Number

    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match(["jmp", Values.NUM]):
            return cls(num=values.numbers[1], rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        return f"jmp {self.num.to_asm(settings)}"

    def get_ram_size(self, ram_pos: int) -> int:
        return 2

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        return ram + bytes([4 << 4, self.num.to_int(label_pos)])

@dataclasses.dataclass
class CJumpRegister(Content):
    reg: Reg

    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match(["jmpr", Values.REG]):
            return cls(reg=values.regs[1], rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        return f"jmpr {self.reg.to_asm(settings)}"

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        return ram + bytes([(3 << 4) + self.reg.idx])

@dataclasses.dataclass
class CJumpConditional(Content):
    conditions: set[chr]
    num: Number
    _jmp_op = {"z": 0, "e": 1, "a": 2, "c": 3}

    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if len(values.raws) == 2 and values.numbers[1] is not None and values.raws[0].lower().startswith("j") and all(x in "zeac" for x in values.raws[0][1:].lower()):
            return cls(conditions=set(values.raws[0][1:].lower()), num=values.numbers[1], rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        return f"j{''.join(self.conditions)} {self.num.to_asm(settings)}"

    def get_ram_size(self, ram_pos: int) -> int:
        return 2

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        tmp = 0
        for cond in self.conditions:
            tmp |= 1 << self._jmp_op[cond]
        return ram + bytes([(5 << 4) + tmp, self.num.to_int(label_pos)])

@dataclasses.dataclass
class CAnd(Content):
    reg_read: Reg
    reg_write: Reg
    reg_write_2: Reg | None = None

    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match(["and", Values.REG, Values.REG]):
            return cls(reg_read=values.regs[1], reg_write=values.regs[2], rest=values.rest)
        if values.match([Values.REG, "&=", Values.REG]):
            return cls(reg_read=values.regs[2], reg_write=values.regs[0], rest=values.rest)
        if values.match([Values.REG, "=", Values.REG, "&", Values.REG]) and values.regs[0].idx == values.regs[2]:
            return cls(reg_read=values.regs[4], reg_write=values.regs[0], reg_write_2=values.regs[2], rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        reg_write_str = self.reg_write.to_asm(settings)
        if settings.asm_style == "c":
            reg_write_2_str = self.reg_write_2.to_asm(settings) if self.reg_write_2 else reg_write_str
            if reg_write_str == reg_write_2_str:
                return f"{reg_write_str} &= {self.reg_read.to_asm(settings)}"
            else:
                return f"{reg_write_str} = {reg_write_2_str} & {self.reg_read.to_asm(settings)}"
        elif settings.asm_style == "asm":
            return f"and {self.reg_read.to_asm(settings)} {reg_write_str}"
        else:
            raise NotImplementedError

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        return ram + bytes([(1 << 7) + (4 << 4) + (self.reg_read.idx << 2) + self.reg_write.idx])

@dataclasses.dataclass
class COr(Content):
    reg_read: Reg
    reg_write: Reg
    reg_write_2: Reg | None = None

    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match(["or", Values.REG, Values.REG]):
            return cls(reg_read=values.regs[1], reg_write=values.regs[2], rest=values.rest)
        if values.match([Values.REG, "|=", Values.REG]):
            return cls(reg_read=values.regs[2], reg_write=values.regs[0], rest=values.rest)
        if values.match([Values.REG, "=", Values.REG, "|", Values.REG]) and values.regs[0].idx == values.regs[2]:
            return cls(reg_read=values.regs[4], reg_write=values.regs[0], reg_write_2=values.regs[2], rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        reg_write_str = self.reg_write.to_asm(settings)
        if settings.asm_style == "c":
            reg_write_2_str = self.reg_write_2.to_asm(settings) if self.reg_write_2 else reg_write_str
            if reg_write_str == reg_write_2_str:
                return f"{reg_write_str} |= {self.reg_read.to_asm(settings)}"
            else:
                return f"{reg_write_str} = {reg_write_2_str} | {self.reg_read.to_asm(settings)}"
        elif settings.asm_style == "asm":
            return f"or {self.reg_read.to_asm(settings)} {reg_write_str}"
        else:
            raise NotImplementedError

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        return ram + bytes([(1 << 7) + (5 << 4) + (self.reg_read.idx << 2) + self.reg_write.idx])

@dataclasses.dataclass
class CXor(Content):
    reg_read: Reg
    reg_write: Reg
    reg_write_2: Reg | None = None

    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match(["xor", Values.REG, Values.REG]):
            return cls(reg_read=values.regs[1], reg_write=values.regs[2], rest=values.rest)
        if values.match([Values.REG, "^=", Values.REG]):
            return cls(reg_read=values.regs[2], reg_write=values.regs[0], rest=values.rest)
        if values.match([Values.REG, "=", Values.REG, "^", Values.REG]) and values.regs[0].idx == values.regs[2]:
            return cls(reg_read=values.regs[4], reg_write=values.regs[0], reg_write_2=values.regs[2], rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        reg_write_str = self.reg_write.to_asm(settings)
        if settings.asm_style == "c":
            reg_write_2_str = self.reg_write_2.to_asm(settings) if self.reg_write_2 else reg_write_str
            if reg_write_str == reg_write_2_str:
                return f"{reg_write_str} ^= {self.reg_read.to_asm(settings)}"
            else:
                return f"{reg_write_str} = {reg_write_2_str} ^ {self.reg_read.to_asm(settings)}"
        elif settings.asm_style == "asm":
            return f"xor {self.reg_read.to_asm(settings)} {reg_write_str}"
        else:
            raise NotImplementedError

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        return ram + bytes([(1 << 7) + (6 << 4) + (self.reg_read.idx << 2) + self.reg_write.idx])

@dataclasses.dataclass
class CNot(Content):
    reg_read: RegT
    reg_write: Reg

    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match(["not", Values.REG, Values.REG]):
            return cls(reg_read=RegT.from_reg(values.regs[1]), reg_write=values.regs[2], rest=values.rest)
        if values.match([Values.REG, "=~", Values.REG]) or values.match([Values.REG, "=!", Values.REG]):
            return cls(reg_read=RegT.from_reg(values.regs[2]), reg_write=values.regs[0], rest=values.rest)
        if values.match([Values.REG, "=", Values.REGT]):
            return cls(reg_read=values.regts[2], reg_write=values.regs[0], rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        if settings.asm_style == "c":
            return f"{self.reg_write.to_asm(settings)} = {self.reg_read.to_asm(settings)}"
        elif settings.asm_style == "asm":
            return f"not {self.reg_read.to_asm(settings)} {self.reg_write.to_asm(settings)}"
        else:
            raise NotImplementedError

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        return ram + bytes([(1 << 7) + (3 << 4) + (self.reg_read.idx << 2) + self.reg_write.idx])

@dataclasses.dataclass
class CAdd(Content):
    reg_read: Reg
    reg_write: Reg
    reg_write_2: Reg | None = None

    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match(["add", Values.REG, Values.REG]):
            return cls(reg_read=values.regs[1], reg_write=values.regs[2], rest=values.rest)
        if values.match([Values.REG, "+=", Values.REG]):
            return cls(reg_read=values.regs[2], reg_write=values.regs[0], rest=values.rest)
        if values.match([Values.REG, "=", Values.REG, "+", Values.REG]) and values.regs[0].idx == values.regs[2]:
            return cls(reg_read=values.regs[4], reg_write=values.regs[0], reg_write_2=values.regs[2], rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        reg_write_str = self.reg_write.to_asm(settings)
        if settings.asm_style == "c":
            reg_write_2_str = self.reg_write_2.to_asm(settings) if self.reg_write_2 else reg_write_str
            if reg_write_str == reg_write_2_str:
                return f"{reg_write_str} += {self.reg_read.to_asm(settings)}"
            else:
                return f"{reg_write_str} = {reg_write_2_str} + {self.reg_read.to_asm(settings)}"
        elif settings.asm_style == "asm":
            return f"add {self.reg_read.to_asm(settings)} {reg_write_str}"
        else:
            raise NotImplementedError

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        return ram + bytes([(1 << 7) + (0 << 4) + (self.reg_read.idx << 2) + self.reg_write.idx])

@dataclasses.dataclass
class CShl(Content):
    reg_read: Reg
    reg_write: Reg

    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match(["shl", Values.REG, Values.REG]):
            return cls(reg_read=values.regs[1], reg_write=values.regs[2], rest=values.rest)
        if values.match([Values.REG, "=<<", Values.REG]):
            return cls(reg_read=values.regs[2], reg_write=values.regs[0], rest=values.rest)
        if values.match([Values.REG, "=", Values.REG, "<<", Values.NUM]) and values.numbers[4].value == 1:
            return cls(reg_read=values.regs[2], reg_write=values.regs[0], rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        if settings.asm_style == "c":
            return f"{self.reg_write.to_asm(settings)} = {self.reg_read.to_asm(settings)} << 1"
        elif settings.asm_style == "asm":
            return f"shl {self.reg_read.to_asm(settings)} {self.reg_write.to_asm(settings)}"
        else:
            raise NotImplementedError

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        return ram + bytes([(1 << 7) + (2 << 4) + (self.reg_read.idx << 2) + self.reg_write.idx])

@dataclasses.dataclass
class CShr(Content):
    reg_read: Reg
    reg_write: Reg

    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match(["shr", Values.REG, Values.REG]):
            return cls(reg_read=values.regs[1], reg_write=values.regs[2], rest=values.rest)
        if values.match([Values.REG, "=>>", Values.REG]):
            return cls(reg_read=values.regs[2], reg_write=values.regs[0], rest=values.rest)
        if values.match([Values.REG, "=", Values.REG, ">>", Values.NUM]) and values.numbers[4].value == 1:
            return cls(reg_read=values.regs[2], reg_write=values.regs[0], rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        if settings.asm_style == "c":
            return f"{self.reg_write.to_asm(settings)} = {self.reg_read.to_asm(settings)} >> 1"
        elif settings.asm_style == "asm":
            return f"shr {self.reg_read.to_asm(settings)} {self.reg_write.to_asm(settings)}"
        else:
            raise NotImplementedError

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        return ram + bytes([(1 << 7) + (1 << 4) + (self.reg_read.idx << 2) + self.reg_write.idx])

@dataclasses.dataclass
class CClf(Content):
    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match(["clf"]):
            return cls(rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        return "clf"

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        return ram + bytes([(6 << 4)])

@dataclasses.dataclass
class CCmp(Content):
    reg_read: Reg
    reg_write: Reg

    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match(["cmp", Values.REG, Values.REG]):
            return cls(reg_read=values.regs[1], reg_write=values.regs[2], rest=values.rest)
        if values.match([Values.REG, "==", Values.REG]):
            return cls(reg_read=values.regs[0], reg_write=values.regs[2], rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        if settings.asm_style == "c":
            return f"{self.reg_read.to_asm(settings)} == {self.reg_write.to_asm(settings)}"
        elif settings.asm_style == "asm":
            return f"cmp {self.reg_read.to_asm(settings)} {self.reg_write.to_asm(settings)}"
        else:
            raise NotImplementedError

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        return ram + bytes([(1 << 7) + (7 << 4) + (self.reg_read.idx << 2) + self.reg_write.idx])

@dataclasses.dataclass
class CLoad(Content):
    reg_read: RegP
    reg_write: Reg

    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match(["ld", Values.REG, Values.REG]):
            return cls(reg_read=RegP.from_reg(values.regs[1]), reg_write=values.regs[2], rest=values.rest)
        if values.match([Values.REG, "=", Values.REGP]):
            return cls(reg_read=values.regps[2], reg_write=values.regs[0], rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        if settings.asm_style == "c":
            return f"{self.reg_write.to_asm(settings)} = {self.reg_read.to_asm(settings)}"
        elif settings.asm_style == "asm":
            return f"ld {self.reg_read.to_asm(settings)} {self.reg_write.to_asm(settings)}"
        else:
            raise NotImplementedError

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        return ram + bytes([(0 << 4) + (self.reg_read.idx << 2) + self.reg_write.idx])

@dataclasses.dataclass
class CStore(Content):
    reg_read: Reg
    reg_write: RegP

    @classmethod
    def from_values(cls, values: Values) -> Self | None:
        if values.match(["st", Values.REG, Values.REG]):
            return cls(reg_read=values.regs[2], reg_write=RegP.from_reg(values.regs[1]), rest=values.rest)
        if values.match([Values.REGP, "=", Values.REG]):
            return cls(reg_read=values.regs[2], reg_write=values.regps[0], rest=values.rest)
        return None

    def to_asm(self, settings: Settings) -> str:
        if settings.asm_style == "c":
            return f"{self.reg_write.to_asm(settings)} = {self.reg_read.to_asm(settings)}"
        elif settings.asm_style == "asm":
            return f"st {self.reg_write.to_asm(settings)} {self.reg_read.to_asm(settings)}"
        else:
            raise NotImplementedError

    def to_ram(self, ram: bytes, label_pos: dict[str, int], settings: Settings) -> bytes:
        return ram + bytes([(1 << 4) + (self.reg_write.idx << 2) + self.reg_read.idx])

@dataclasses.dataclass
class Line:
    indent: LineIndent
    content: Content
    comment: LineComment | None
    raw_line: str
    line_number: int

    @classmethod
    def from_text(cls, text: str, line_number: int) -> Self | None:
        indent = LineIndent.from_text(text)
        if indent is None:
            return None
        for c_cls in Content.__subclasses__():
            content = c_cls.from_values(Values.from_text(indent.rest))
            if content:
                break
        else:
            return None
        comment = LineComment.from_text(content.rest)
        if comment is None:
            return None
        return cls(indent=indent, content=content, comment=comment, raw_line=text, line_number=line_number)

    def to_asm(self, settings: Settings) -> str:
        ret = self.indent.to_asm(settings) + self.content.to_asm(settings)
        if self.comment:
            ret += self.comment.to_asm(settings)
        return ret

class AsmProgram:
    def __init__(self, asm_file: str, settings: Settings):
        self.lines: list[Line] = []
        self.errors: list[str] = []
        self.settings = settings

        for count, raw_line in enumerate(pathlib.Path(asm_file).read_text().split("\n")):
            line = Line.from_text(raw_line, count + 1)
            if line:
                self.lines.append(line)
            else:
                self.errors.append(f"Line {count+1}: Invalid line: '{raw_line}'")

        self.label_pos = {}
        ram_pos = 0
        for line in self.lines:
            if isinstance(line.content, CLabel):
                label_pos = ram_pos + line.content.offset
                if label_pos >= 256:
                    self.errors.append(f"Label {line.content.name} points at ram pos {label_pos} >= 256")
                else:
                    self.label_pos[line.content.name] = ram_pos + line.content.offset
            try:
                ram_pos += line.content.get_ram_size(ram_pos)
            except ValueError as error:
                self.errors.append(f"Line {line.line_number}: {line.raw_line}: Error getting ram size: {error!s}")

        self.ram = b""
        for line in self.lines:
            try:
                self.ram = line.content.to_ram(self.ram, self.label_pos, self.settings)
            except ValueError as error:
                self.errors.append(f"Line {line.line_number}: {line.raw_line}: Error compiling: {error!s}")

    def to_asm(self) -> str:
        return "\n".join(line.to_asm(self.settings) for line in self.lines)

    def to_ram(self) -> bytes:
        return self.ram

def main(argv):
    parser = argparse.ArgumentParser(prog="8bit ASM compiler")
    parser.add_argument("-c", "--config")
    cmd_parser = parser.add_subparsers(dest="cmd")
    cmd_format = cmd_parser.add_parser("format")
    cmd_format.add_argument("-i", "--in-place", action="store_true")
    cmd_format.add_argument("asm_file_in")
    cmd_compile = cmd_parser.add_parser("compile")
    cmd_compile.add_argument("asm_file_in")
    cmd_compile.add_argument("ram_file_out")
    parsed = parser.parse_args(argv[1:])
    config_file = pathlib.Path(parsed.config or "minicomp.config.json")
    if config_file.exists():
        settings = Settings.model_validate_json(config_file.read_text())
    else:
        settings = Settings()
    asm_program = AsmProgram(parsed.asm_file_in, settings=settings)
    if asm_program.errors:
        for error in asm_program.errors:
            print(error)
        return
    if parsed.cmd == "format":
        if parsed.in_place:
            pathlib.Path(parsed.asm_file_in).write_text(asm_program.to_asm())
        else:
            print(asm_program.to_asm(), end="")
    elif parsed.cmd == "compile":
        pathlib.Path(parsed.ram_file_out).write_bytes(asm_program.to_ram())

if __name__ == "__main__":
    main(sys.argv)
