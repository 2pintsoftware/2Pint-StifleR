use std::path::Path;

#[tauri::command]
async fn get_meeting_audio_path(meeting_folder: String) -> Result<Option<String>, String> {
    let folder_path = Path::new(&meeting_folder);
    
    // Validate the path by canonicalizing it
    let canonical_path = folder_path.canonicalize()
        .map_err(|e| format!("Failed to resolve path: {}", e))?;
    
    if !canonical_path.is_dir() {
        return Err(format!("Path is not a directory: {}", meeting_folder));
    }
    
    // Search for audio files with common extensions
    let audio_extensions = ["mp4", "wav", "mp3", "m4a", "webm", "ogg"];
    
    let entries = std::fs::read_dir(&canonical_path)
        .map_err(|e| format!("Failed to read directory: {}", e))?;
    
    // Collect all audio files and sort them for consistent ordering
    let mut audio_files: Vec<_> = entries
        .filter_map(|entry| entry.ok())
        .filter_map(|entry| {
            let path = entry.path();
            if path.is_file() {
                if let Some(extension) = path.extension() {
                    let ext_lower = extension.to_string_lossy().to_lowercase();
                    if audio_extensions.contains(&ext_lower.as_str()) {
                        return Some(path);
                    }
                }
            }
            None
        })
        .collect();
    
    // Sort alphabetically for consistent results
    audio_files.sort();
    
    Ok(audio_files.first().map(|p| p.to_string_lossy().to_string()))
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![get_meeting_audio_path])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs::File;
    use tempfile::tempdir;

    #[tokio::test]
    async fn test_get_meeting_audio_path_with_mp4() {
        let dir = tempdir().unwrap();
        let audio_path = dir.path().join("recording.mp4");
        File::create(&audio_path).unwrap();

        let result = get_meeting_audio_path(dir.path().to_string_lossy().to_string()).await;
        
        assert!(result.is_ok());
        let path = result.unwrap();
        assert!(path.is_some());
        assert!(path.unwrap().ends_with("recording.mp4"));
    }

    #[tokio::test]
    async fn test_get_meeting_audio_path_with_wav() {
        let dir = tempdir().unwrap();
        let audio_path = dir.path().join("audio.wav");
        File::create(&audio_path).unwrap();

        let result = get_meeting_audio_path(dir.path().to_string_lossy().to_string()).await;
        
        assert!(result.is_ok());
        let path = result.unwrap();
        assert!(path.is_some());
        assert!(path.unwrap().ends_with("audio.wav"));
    }

    #[tokio::test]
    async fn test_get_meeting_audio_path_no_audio() {
        let dir = tempdir().unwrap();
        // Create a non-audio file
        let text_path = dir.path().join("notes.txt");
        File::create(&text_path).unwrap();

        let result = get_meeting_audio_path(dir.path().to_string_lossy().to_string()).await;
        
        assert!(result.is_ok());
        assert!(result.unwrap().is_none());
    }

    #[tokio::test]
    async fn test_get_meeting_audio_path_invalid_folder() {
        let result = get_meeting_audio_path("/nonexistent/folder/path".to_string()).await;
        
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_get_meeting_audio_path_multiple_files_returns_first_alphabetically() {
        let dir = tempdir().unwrap();
        // Create multiple audio files
        File::create(dir.path().join("zebra.mp4")).unwrap();
        File::create(dir.path().join("alpha.mp4")).unwrap();
        File::create(dir.path().join("beta.wav")).unwrap();

        let result = get_meeting_audio_path(dir.path().to_string_lossy().to_string()).await;
        
        assert!(result.is_ok());
        let path = result.unwrap();
        assert!(path.is_some());
        // Should return alpha.mp4 as it's first alphabetically
        assert!(path.unwrap().ends_with("alpha.mp4"));
    }
}
