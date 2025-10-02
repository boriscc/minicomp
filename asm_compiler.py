"""Legacy ASM compiler.

Use asm.py instead.
"""

import collections
import dataclasses
import sys
import pathlib

alu_op = {"add": 0, "shr": 1, "shl": 2, "not": 3, "and": 4, "or": 5, "xor": 6, "cmp": 7}
other_op = {"ld": 0, "st": 1, "data": 2, "jmpr": 3, "jmp": 4, "jxxx": 5, "clf": 6, "io": 7}
io_op = {"ind": 0, "ina": 4, "outd": 8, "outa": 12}
jmp_op = {"z": 0, "e": 1, "a": 2, "c": 3}
reg_id = {"ra": 0, "rb": 1, "rc": 2, "rd": 3}

@dataclasses.dataclass
class LabelInfo:
    location: int | None = None
    use_positions: list[int] = dataclasses.field(default_factory=list)

label_map: dict[str, LabelInfo] = collections.defaultdict(LabelInfo)
ram_pos = 0
ram = bytearray(256)

def as_reg(token: str) -> int:
    return reg_id[token[:2].lower()]

def add_label_usage(label_name: str, pos: int) -> None:
    label_map[label_name].use_positions.append(pos)

def as_number(token: str, token_pos: int | None = None) -> int:
    if not token:
        raise RuntimeError(f"Invalid number: '{token}'")
    if token[0] == "$":
        if token_pos is None:
            raise ValueError("Missing token_pos")
        add_label_usage(token[1:].lower(), token_pos)
        return 0
    if len(token) == 3 and token[0] == "'" and token[2] == "'":
        return ord(token[1])
    if token.lower().startswith("0x"):
        return int(token[2:], 16)
    if token.lower().startswith("0b"):
        return int(token[2:], 2)
    if len(token) == 8:
        return int(token, 2)
    return int(token, 10)

for raw_line in pathlib.Path(sys.argv[1]).read_text().split("\n"):
    tokens = [a.replace("''", "' '").replace("///", "'#'") for a in raw_line.replace("'#'", "///").split("#")[0].strip().replace("' '", "''").split()]
    if not tokens:
        continue
    if len(tokens) == 1:
        if tokens[0].lower() == "clf":
            ram[ram_pos] = other_op["clf"] << 4
            ram_pos += 1
            continue
        if tokens[0][-1] == ":":
            if tokens[0][-2] == ":":
                label_name = tokens[0][:-2]
                label_pos = ram_pos + 1
            else:
                label_name = tokens[0][:-1]
                label_pos = ram_pos
            label_map[label_name.lower()].location = label_pos
            continue
    if tokens[0].lower() == "pragma":
        pragma = tokens[1].lower()
        if pragma == "pos" and len(tokens) == 3:
            expected_pos = as_number(tokens[2])
            if expected_pos != ram_pos:
                raise RuntimeError(f"Expected {expected_pos=} to be {ram_pos=}")
        elif pragma == "setpos" and len(tokens) == 3:
            new_pos = as_number(tokens[2])
            if new_pos < ram_pos:
                raise RuntimeError(f"Expected {new_pos=} to be >= {ram_pos=}")
            ram_pos = new_pos
        elif pragma == "printpos" and len(tokens) == 2:
            print(f"Next RAM position: {ram_pos}")
        else:
            raise NotImplementedError(pragma)
        continue
    if tokens[0] == "." and len(tokens) == 2:
        ram[ram_pos] = as_number(tokens[1], ram_pos)
        ram_pos += 1
        continue
    if len(tokens) == 3:
        if tokens[1] == "=":
            if tokens[2].startswith("!"):
                tokens = ["not", tokens[2][1:], tokens[0]]
            elif tokens[2].startswith("*"):
                tokens = ["ld", tokens[2][1:], tokens[0]]
            elif tokens[0].startswith("*"):
                tokens = ["st", tokens[0][1:], tokens[2]]
            else:
                tokens = ["data", tokens[0], tokens[2]]
        elif tokens[1] == "+=":
            tokens = ["add", tokens[2], tokens[0]]
        elif tokens[1] == "&=":
            tokens = ["and", tokens[2], tokens[0]]
        elif tokens[1] == "^=":
            tokens = ["xor", tokens[2], tokens[0]]
        elif tokens[1] == "|=":
            tokens = ["or", tokens[2], tokens[0]]
        elif tokens[1] == "=<<":
            tokens = ["shl", tokens[2], tokens[0]]
        elif tokens[1] == "=>>":
            tokens = ["shr", tokens[2], tokens[0]]
    oper = tokens[0].lower()
    arg1 = tokens[1]
    arg2 = tokens[2] if len(tokens) > 2 else None
    if oper in alu_op and arg2 is not None:
        ram[ram_pos] = 128 + (alu_op[oper] << 4) + (as_reg(arg1) << 2) + as_reg(arg2)
    elif oper in {"ld", "st"} and arg2 is not None:
        ram[ram_pos] = (other_op[oper] << 4) + (as_reg(arg1) << 2) + as_reg(arg2)
    elif oper == "data" and arg2 is not None:
        ram[ram_pos] = (other_op[oper] << 4) + as_reg(arg1)
        ram_pos += 1
        ram[ram_pos] = as_number(arg2, ram_pos)
    elif oper == "jmpr" and arg2 is None:
        ram[ram_pos] = (other_op[oper] << 4) + as_reg(arg1)
    elif oper == "jmp" and arg2 is None:
        ram[ram_pos] = (other_op[oper] << 4)
        ram_pos += 1
        ram[ram_pos] = as_number(arg1, ram_pos)
    elif oper in io_op and arg2 is None:
        ram[ram_pos] = (other_op["io"] << 4) + io_op[oper] + as_reg(arg1)
    elif oper.startswith("j") and arg2 is None:
        value = other_op["jxxx"] << 4
        for idx in oper[1:]:
            value |= 1 << jmp_op[idx]
        ram[ram_pos] = value
        ram_pos += 1
        ram[ram_pos] = as_number(arg1, ram_pos)
    else:
        print(tokens)
        raise RuntimeError(f"Invalid line: '{raw_line}'")
    ram_pos += 1

for name, info in label_map.items():
    if info.location is None:
        raise RuntimeError(f"Missing label '{name}', used at locations {info.use_positions}")
    for use_position in info.use_positions:
        ram[use_position] = info.location

pathlib.Path(sys.argv[2]).write_bytes(ram)
