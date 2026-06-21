# Asset Manifest — A Maze

รายชื่อ asset ที่หามาให้ (เช็คแล้วว่าโหลดได้จริง + license CC0/ตรวจแล้ว) จัดตามโฟลเดอร์ใน `assets/`
ให้ Claude Code โหลดไฟล์จากลิงก์ตรงด้านล่าง แตก/แปลงไฟล์ แล้ววางในโฟลเดอร์ที่ระบุ จากนั้นไป wire เข้ากับ
`maze_level.gd` (texture), `player.gd` (footstep + ของในมือ), `chalk_mark.gd`/ghost AI (model + sfx) ต่อเอง

ทุกลิงก์ผ่านการ fetch ตรวจสอบแล้วว่าเปิดได้และ license ตรงตามที่ระบุ ณ วันที่ทำ manifest นี้ (2026-06-22)

---

## 1. textures/ — PolyHaven (CC0, ตรวจแล้วทุกอัน)

แต่ละ asset มีให้เลือกหลาย resolution/format ในหน้าเว็บ — ด้านล่างคือลิงก์ตรงแบบ **JPG 2K**
(เบาพอสำหรับเกม, ถ้าอยากได้คมกว่านี้เปลี่ยน `2k` → `4k`/`8k` ในลิงก์ได้เลย)

### textures/inner_stone/ — Zone 0 (แดงน้ำตาล, Color(0.22,0.14,0.13))
**Brick Wall 001** — https://polyhaven.com/a/brick_wall_001
อิฐแดงหยาบ สีน้ำตาลแดงเข้ม ตรงกับ inner zone ตรงๆ
- Diffuse: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/brick_wall_001/brick_wall_001_diffuse_2k.jpg
- Normal (GL, ใช้กับ Godot): https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/brick_wall_001/brick_wall_001_nor_gl_2k.jpg
- ARM (AO/Roughness/Metal รวมไฟล์เดียว): https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/brick_wall_001/brick_wall_001_arm_2k.jpg
- License: CC0

### textures/middle_stone/ — Zone 1 (หิน, Color(0.17,0.14,0.11))
**Stone Brick Wall 001** — https://polyhaven.com/a/stone_brick_wall_001
หินก่อกำแพง dungeon/fort โดยตรง (tag มีคำว่า "dungeon" ด้วย)
- Diffuse: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/stone_brick_wall_001/stone_brick_wall_001_diff_2k.jpg
- Normal (GL): https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/stone_brick_wall_001/stone_brick_wall_001_nor_gl_2k.jpg
- ARM: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/stone_brick_wall_001/stone_brick_wall_001_arm_2k.jpg
- License: CC0

### textures/outer_stone/ — Zone 2 (ม่วง, Color(0.12,0.10,0.16))
**Stone Wall 04** — https://polyhaven.com/a/stone_wall_04
หินสีเทากลางๆ ไม่มี texture หินสีม่วงจริงๆใน CC0 — ใช้ตัวนี้เป็นฐานสีเทา แล้วทับด้วย
`albedo_color = Color(0.45, 0.35, 0.6)` คูณกับ albedo_texture ใน `StandardMaterial3D` เพื่อให้ออกม่วงตามโทนเกม
- Diffuse: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/stone_wall_04/stone_wall_04_diff_2k.jpg
- Normal (GL): https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/stone_wall_04/stone_wall_04_nor_gl_2k.jpg
- ARM: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/stone_wall_04/stone_wall_04_arm_2k.jpg
- License: CC0

### textures/floor_ceiling/ — floor_mat / ceil_mat (Color(0.09,0.08,0.09) / Color(0.07,0.06,0.08))
**Damaged Concrete Floor** — https://polyhaven.com/a/damaged_concrete_floor
พื้นปูนเก่าๆ มีรอยแตก/คราบ ใช้ได้ทั้งพื้นและเพดาน (เพดานลด albedo ลงอีกหน่อยให้เข้ากับ Color เดิม)
- Diffuse: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/damaged_concrete_floor/damaged_concrete_floor_diff_2k.jpg
- Normal (GL): https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/damaged_concrete_floor/damaged_concrete_floor_nor_gl_2k.jpg
- ARM: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/damaged_concrete_floor/damaged_concrete_floor_arm_2k.jpg
- License: CC0

### ambientCG (สำรอง / ยังไม่ได้ตรวจตรงๆ)
ambientCG ทุกหน้าเป็น client-rendered JS ทำให้ sandbox นี้ fetch ไม่ได้เลย (ทั้ง HTML และ JSON API คืนค่าง่าง)
ถ้าอยาก diversify texture เพิ่ม ลองเข้าเอง: https://ambientcg.com/view?id=Bricks066 (Stone Wall, พบจาก WebSearch
แต่ไม่ได้ verify ตรงด้วยตัวเอง) — ต้องกด Download เองแล้วเลือก resolution/format ในหน้าเว็บ

---

## 2. models/ — Kenney (CC0, ตรวจแล้ว, มีลิงก์ ZIP ตรง) + Quaternius (CC0, ต้องกด Download เอง)

### models/dungeon_kit/
**Mini Dungeon** (Kenney) — 25 assets, animated + variations, tag: dungeon/rpg/roguelike/medieval
- Page: https://kenney.nl/assets/mini-dungeon
- ZIP ตรง: https://kenney.nl/media/pages/assets/mini-dungeon/6cd72dc849-1771249391/kenney_mini-dungeon.zip
- License: CC0

**Modular Dungeon Kit** (Kenney) — 40 assets, ผนัง/พื้น/ประตู modular ต่อกันเป็น maze ได้ตรงคอนเซปต์เกม
- Page: https://kenney.nl/assets/modular-dungeon-kit
- ZIP ตรง: https://kenney.nl/media/pages/assets/modular-dungeon-kit/7bed87605b-1771926065/kenney_modular-dungeon-kit_1.0.zip
- License: CC0

**Modular Dungeons Pack** (Quaternius) — modular dungeon, statues, ใช้เสริม prop เพิ่มความหลากหลาย
- Page (กด Download บนหน้านี้เอง, เป็น JS modal เลือก mirror Google Drive/Mega): https://quaternius.com/packs/modulardungeon.html
- Format: FBX/OBJ/Blend — License: CC0

### models/props/
**Graveyard Kit** (Kenney) — 90 assets, tag: graveyard/halloween/horror/monster/spooky — เหมาะกับโทนเกมมาก
- Page: https://kenney.nl/assets/graveyard-kit
- ZIP ตรง: https://kenney.nl/media/pages/assets/graveyard-kit/ba8d4b4517-1760691807/kenney_graveyard-kit_5.0.zip
- License: CC0

**Survival Pack** (Quaternius) — 53 models รวม compass, flashlight, torch, matches, knife — ตรงกับไอเทมในมือ
player (flashlight ตอนนี้เป็น SpotLight3D เปล่าๆ ไม่มี mesh, เอา flashlight model จากแพ็คนี้มาแปะใต้กล้องได้)
- Page (กด Download เอง): https://quaternius.com/packs/survival.html
- Format: FBX/OBJ/Blend — License: CC0

**Cute Animated Monsters Pack** (Quaternius) — 21 monster มี ghost model ในแพ็ค (มี texture + animation ในตัว)
ใช้เป็น placeholder mesh ให้ ghost AI ได้เลย ถ้าโทน "cute" ไม่เข้ากับเกม horror ให้ปรับ material ให้มืด/scale ใหญ่ขึ้นชดเชย
- Page (กด Download เอง): https://quaternius.com/packs/cutemonsters.html
- Format: FBX/OBJ/Blend/glTF — License: CC0

> หมายเหตุ Quaternius: หน้า pack เป็น static HTML แต่ปุ่ม Download เป็น JS modal (เลือก mirror) — sandbox นี้ดึงลิงก์
> ตรงไม่ได้ ต้องเปิดหน้าเว็บแล้วกด Download เอง ทุก pack ยืนยันแล้วว่า license = CC0

---

## 3. sounds/ — Kenney (CC0, ลิงก์ตรง) + OpenGameArt (เช็ค license ทีละไฟล์ตามที่ระบุ)

### sounds/footsteps/
**RPG Audio** (Kenney) — 50 ไฟล์, tag: foley/rpg/**footstep**/weapon — มีเสียงเดินหลายพื้นผิวให้เลือก
ใช้กับ `player.gd` → `step_audio.stream` (ตอนนี้ stream เป็น null, ยังไม่ได้ผูกเสียงเดินเลย)
- Page: https://kenney.nl/assets/rpg-audio
- ZIP ตรง: https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip
- License: CC0

### sounds/ambient/
**Ambient horror** (OpenGameArt, by techiew) — เสียง ambience น่ากลัวยาว ใช้วน loop พื้นหลังทั้งเกมได้
- Page: https://opengameart.org/content/ambient-horror
- ไฟล์ตรง (ogg, 776KB): https://opengameart.org/sites/default/files/ambient_horror_0.ogg
- ไฟล์ตรง (wav, 4.3MB): https://opengameart.org/sites/default/files/ambient_horror.wav
- License: **CC0**

**4 Atmospheric ghostly loops** (OpenGameArt, by Independent.nu) — 4 loop เสียง dark/ghost/atmosphere แยกเป็นโซนได้
(เช่น โซนละ loop หรือสลับตาม danger_level)
- Page: https://opengameart.org/content/4-atmospheric-ghostly-loops
- ไฟล์ตรง (.7z รวม 4 loop, 3.4MB): https://opengameart.org/sites/default/files/independent_nu_ljudbank-atmosphere_moody.7z
- License: **CC0**

**Horror Sound Effects Library** (OpenGameArt, by Little Robot Sound Factory) — 69 เสียง รวม 5 ambience,
19 breathing-scared one-shot, 12 monster/zombie, 1 gate-open ฯลฯ — เก็บไว้ใช้ได้หลายจุด (ดูหมวด ghost/sfx ด้านล่างด้วย)
- Page: https://opengameart.org/content/horror-sound-effects-library
- ไฟล์ตรง (.zip 70MB, รวมทุกเสียง): https://opengameart.org/sites/default/files/Horror%20Sound%20Library.zip
- License: **CC-BY 3.0 — ต้อง credit "Little Robot Sound Factory"** ในเกม/credits

### sounds/ghost/
จากแพ็ค **Horror Sound Effects Library** ด้านบน (แตก zip แล้วเลือกใช้เฉพาะไฟล์ที่ต้องการ):
- โฟลเดอร์ "Breathing Scared One Shots" (19 ไฟล์) → ใช้เป็นเสียงหายใจตอน ghost เข้าใกล้ (ผูกกับ `danger_level`)
- โฟลเดอร์ "Monster and Zombie" (12 ไฟล์) → ใช้เป็นเสียง growl/snarl ของ ghost
- License เดิม: **CC-BY 3.0 — ต้อง credit**

### sounds/sfx/
**Glass Break** (OpenGameArt, by Till Behrend/TinyWorlds) — เสียงกระจกแตก เหมาะกับกลไก mirror
- Page: https://opengameart.org/content/glass-break
- ไฟล์ตรง (wav, 230KB): https://opengameart.org/sites/default/files/glass_breaking.wav
- License: **CC0**

**Interface Sounds** (Kenney) — 100 ไฟล์เสียง click/button/chime — ใช้ทำเสียงเก็บ clue/chalk และ unlock exit ได้
- Page: https://kenney.nl/assets/interface-sounds
- ZIP ตรง: https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip
- License: CC0

**Gate Open** (จากแพ็ค Horror Sound Effects Library ด้านบน, ไฟล์เดียวในแพ็ค) → ใช้เป็นเสียง exit unlock ได้พอดี
- License: CC-BY 3.0 (เหมือนแพ็คเดิม)

> **เสียงที่ยังหาไม่เจอ:** ไม่มีเสียง "ขีดชอล์ก" (chalk scratch) แบบ CC0 ตรงๆใน OpenGameArt — แนะนำให้:
> 1) ลองตัด/pitch-shift เสียง foley จาก Kenney RPG Audio มาแทน หรือ
> 2) เข้าไปหาเองที่ Freesound.org (ค้นคำว่า "chalk write" หรือ "pencil scratch", กรอง license = CC0) — sandbox
>    นี้ fetch freesound.org ไม่ได้เลย (เป็น JS app เต็มตัว, หน้าเปล่าทุกหน้าแม้แต่หน้า sound เดี่ยวๆ) ต้องเข้าเว็บเอง

---

## 4. โฟลเดอร์เก่า
`assets/materials/` เป็นโฟลเดอร์เปล่าจากก่อนหน้านี้ ถูกแทนที่ด้วย `textures/{inner,middle,outer}_stone/` +
`textures/floor_ceiling/` แล้ว — ลบทิ้งได้เลยถ้าไม่มีอะไรอ้างถึงใน .tscn/.gd

---

## สรุปสิ่งที่ต้องทำต่อ (สำหรับ Claude Code)
1. โหลดไฟล์ทุกลิงก์ข้างบน (Kenney + OpenGameArt มีลิงก์ตรง, ดาวน์โหลดได้ทันที / Quaternius ต้องเปิดหน้าเว็บกด Download)
2. แตก zip/7z แล้วแยกไฟล์ตามโฟลเดอร์ที่ระบุ
3. ผูก texture เข้ากับ `_mat()` ใน `maze_level.gd` (ใส่ albedo_texture + normal_texture, ของ outer ใส่ albedo_color ม่วงทับด้วย)
4. ผูกเสียงเดินเข้า `player.gd` → `step_audio.stream`
5. ผูกเสียง ambient/ghost เข้ากับ AudioStreamPlayer ของ ghost AI script และ danger_level
6. เพิ่ม credit "Little Robot Sound Factory" ใน credits ของเกม (สำหรับไฟล์ CC-BY 3.0 ที่ใช้)
7. ลบ `assets/materials/` ถ้าไม่มีอะไรอ้างถึง
