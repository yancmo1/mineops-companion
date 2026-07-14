# Kolibri Save Data: Exact Commands Used

> This is a transcript-style runbook of the exact shell commands used in-chat to fetch and decode save data.

## 1) Probe Capsule API with auth header

```bash
curl -v -H "authorization: M8XMbdJKrSZMZL2nxd2vH2tFWE6m7LaJwY7hNsTQavtZ65Xe8AztsR==" "https://capsule.kolibrigames.com/api/client/v1/games/com.fluffyfairygames.idleminertycoon/players/dbffca92-27e9-485a-831a-feb5bfc2e3c4/savegame?saveGameKey=0" 2>&1 | head -50
```

## 2) Download raw save payload

```bash
curl -s -H "authorization: M8XMbdJKrSZMZL2nxd2vH2tFWE6m7LaJwY7hNsTQavtZ65Xe8AztsR==" -H "x-unity-version: 2022.3.62f2" -H "user-agent: IdleMiner/96354" "https://capsule.kolibrigames.com/api/client/v1/games/com.fluffyfairygames.idleminertycoon/players/dbffca92-27e9-485a-831a-feb5bfc2e3c4/savegame?saveGameKey=0" -o ~/Desktop/game-save.bin 2>&1 && echo "Saved to ~/Desktop/game-save.bin" && ls -la ~/Desktop/game-save.bin
```

## 3) Inspect file header/format

```bash
cd ~/Desktop && file game-save.bin && hexdump -n 4 game-save.bin && gunzip -k game-save.bin 2>&1 || echo "Not gzip, trying as raw data"
```

```bash
head -c 500 ~/Desktop/game-save.bin | xxd | head -20
```

```bash
cd ~/Desktop
head -c 200 game-save.bin
echo ""
echo "=== last 50 bytes ==="
tail -c 50 game-save.bin | xxd
echo "=== file size ==="
wc -c game-save.bin
```

## 4) Decode payload (strip custom 4-byte prefix + base64 decode)

```bash
cd ~/Desktop
tail -c +5 game-save.bin | base64 -d -o game-save-decoded.bin 2>&1
echo "Exit: $?"
file game-save-decoded.bin
ls -la game-save-decoded.bin
head -c 20 game-save-decoded.bin | xxd
```

## 5) Decompress (strip leading null byte, then gunzip)

```bash
cd ~/Desktop
tail -c +2 game-save-decoded.bin | gunzip -c 2>&1 | head -c 1000
echo ""
echo "---exit: $?"
```

## 6) Save full JSON to disk

```bash
cd ~/Desktop
tail -c +2 game-save-decoded.bin | gunzip -c > game-save-full.json 2>&1
echo "Exit: $?"
wc -c game-save-full.json
```

## 7) Search JSON for Super Manager structures

```bash
cd ~/Desktop
grep -o '"SuperManager[^"]*"' game-save-full.json | head -20
echo "---"
grep -o '"superManager[^"]*"' game-save-full.json | head -20
```

## 8) Inspect SM data path (`Data.SuperManagers.Managers`)

```bash
cd ~/Desktop
python3 -c "
import json
with open('game-save-full.json') as f:
    data = json.load(f)
if 'SuperManagers' in data:
    print('Top-level SuperManagers found')
    sm_data = data['SuperManagers']
    print(type(sm_data))
    print(json.dumps(sm_data, indent=2)[:3000])
elif 'Data' in data and 'SuperManagers' in data['Data']:
    print('Found in Data.SuperManagers')
    sm_data = data['Data']['SuperManagers']
    print(type(sm_data))
    print(json.dumps(sm_data, indent=2)[:3000])
else:
    for key in data.keys():
        print(f'Top key: {key}')
    if 'Data' in data:
        for key in data['Data'].keys():
            print(f'  Data key: {key}')
"
```

## 9) Build tracker-format JSON from raw save (`sm-from-save.json`)

```bash
cd ~/Desktop
python3 -c "
import json
import subprocess

with open('game-save-full.json') as f:
    data = json.load(f)

sm_list = data['Data']['SuperManagers']['Managers']

result = subprocess.run(['curl', '-s', 'https://idle-miners.com/api/sm-data'], capture_output=True, text=True)
if result.returncode == 0:
    sm_defaults = json.loads(result.stdout)
    id_to_name = {sm['gameId']: sm['id'] for sm in sm_defaults}
    print(f'Loaded {len(id_to_name)} SM definitions from fan site')
else:
    id_to_name = {}

print(f'\nTotal SMs in save: {len(sm_list)}')
print()

tracker = {}
for sm in sm_list:
    sm_id = sm['Id']
    name = id_to_name.get(sm_id, f'unknown_{sm_id}')
    tracker[name] = {
        'unlocked': sm['Hired'] is not None if isinstance(sm.get('Hired'), dict) else True,
        'rank': sm.get('Rank', 0),
        'level': sm.get('Level', 1),
        'promoted': sm.get('Promotion', 0),
        'fragments': 0,
        'chronoExcluded': False,
        'tierlistExcluded': False
    }
    print(f'  {name:35s} gameId={sm_id:5d} | R{sm["Rank"]} L{sm["Level"]} P{sm["Promotion"]} Area={sm["Area"]}')

with open('sm-from-save.json', 'w') as f:
    json.dump(tracker, f, indent=2)
print(f'\nSaved to sm-from-save.json ({len(tracker)} SMs)')
"
```

---

## Notes on payload format we observed

- `game-save.bin` started with a custom 4-byte prefix: `U58U`
- Remainder decoded via base64 to `game-save-decoded.bin`
- `game-save-decoded.bin` had a leading null byte before gzip header (`00 1f 8b ...`)
- Stripping the first byte and gunzipping produced JSON (`game-save-full.json`)

## Output files created in session

- `~/Desktop/game-save.bin`
- `~/Desktop/game-save-decoded.bin`
- `~/Desktop/game-save-full.json`
- `~/Desktop/sm-from-save.json`
