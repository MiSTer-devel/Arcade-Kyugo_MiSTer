# Kyugo equivalence-test config (controllers.sv, CTL-2026-10-25). See gen.py / tb_integ.sv.
# Old = keyboard block + m_* wiring (rotated D-pad; pad 1's Btn 2 also presses P2's Btn 2, kept: user decision pending)
# + board bytes; new = ctl_keyboard + the same (untouched) m_* wiring. Keyboard polarity was already correct and pad 2 has
# no Start: no intended difference applies, so new == old exactly.
NEW_TOP = '../../Arcade-Kyugo.sv'
CLK = 'CLK_49M'
OLD_RANGES = [(r'^reg btn_up', r'^wire m_pause'), (r'^wire \[7:0\] p1_controls', r'^wire \[7:0\] sys_controls')]
NEW_RANGES = [(r'^// CTL-2026-10-25: original keyboard block', r'^wire m_pause'),
              (r'^wire \[7:0\] p1_controls', r'^wire \[7:0\] sys_controls')]
DROP = [r'^\s*wire\s+pause_cpu\s*;']
OUT = ['p1_controls', 'p2_controls', 'sys_controls', 'm_pause']
OUT_W = 25
CLASSES = {}
CODES = [0x2C]
THR = [64]
