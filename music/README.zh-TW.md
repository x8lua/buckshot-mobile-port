# 音樂 OTA 更新

支援此功能的 App 啟動時會讀取本目錄的 `manifest.json`。音樂檔下載到
`user://music_ota`，不需要重新簽署 IPA；第一次安裝含 OTA 功能的版本仍需簽署。
目前清單為空，因此所有歌曲維持內建版本。

1. 準備你有權公開的 OGG Vorbis 或 WAV 音樂，每檔最多 64 MiB。
2. 在 `x8lua/buckshot-mobile-port` 的 GitHub Release 上傳音樂檔。
   建議每次使用新的 Release tag 或檔名，避免 CDN 舊快取。
3. 在 PowerShell 執行 `Get-FileHash 'C:\music\track.ogg' -Algorithm SHA256`，
   複製雜湊並轉成小寫。
4. 修改 `music/manifest.json` 並提交到 `main`。下一次啟動 App 會檢查更新。

```json
{
  "schema": 1,
  "tracks": {
    "batch_0": {
      "url": "https://github.com/x8lua/buckshot-mobile-port/releases/download/music-v1/track.ogg",
      "sha256": "填入64字元的小寫SHA256",
      "format": "ogg",
      "loop": true
    }
  }
}
```

可用 ID：`menu`、`batch_0`、`batch_1`、`batch_2`，以及各批次的
`batch_0_secondloop`、`batch_1_secondloop`、`batch_2_secondloop`。
一般歌曲和死亡後第二段歌曲分別設定；未列出的 ID 使用內建音樂。
只接受同一 repository 的 HTTPS Release 下載連結或 `main/music/` raw 連結。

歌曲保持原本 BPM 燈光及低通濾波設定；替換曲目若 BPM 差異大，燈光節拍不會
自動跟隨新曲。音量也沿用遊戲設定，請事先處理音檔音量。

SHA256 不符、下載失敗或無法解碼時，保留上一版有效音樂；沒有快取則用內建。
更新不會中斷正在播放的曲目，下一次載入歌曲時才套用。
關閉 App 再開啟才會重新檢查清單。刪除清單中的 ID 可在下次成功同步後恢復內建音樂。
成功更新後會清除不再使用的音樂快取。這個功能僅更新音訊，不下載程式碼。

驗證指令：

```powershell
python ci/test_music_ota.py --godot C:\tools\godot.exe --project C:\game
```
