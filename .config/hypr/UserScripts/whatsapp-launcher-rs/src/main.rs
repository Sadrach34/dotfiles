use std::process::Command;
use std::thread::sleep;
use std::time::Duration;
use serde_json::Value;

fn main() {
    match handle_whatsapp_launch() {
        Ok(_) => println!("WhatsApp launched successfully"),
        Err(e) => eprintln!("Error: {}", e),
    }
}

fn handle_whatsapp_launch() -> Result<(), Box<dyn std::error::Error>> {
    let current_ws = get_current_workspace()?;
    
    // KISS: Simple logic based on current workspace
    if current_ws == "special" {
        // In special workspace - use special firefox or create new instance
        if has_special_firefox()? {
            focus_special_firefox()?;
            sleep(Duration::from_millis(500));
            
            // Check if WhatsApp tab already exists
            if let Some(tab_id) = find_whatsapp_tab()? {
                focus_whatsapp_tab(tab_id)?;
            } else {
                launch_firefox_tab()?;
            }
        } else {
            launch_firefox_instance()?;
        }
    } else {
        // In normal workspace - use normal firefox or create new instance  
        if has_normal_firefox()? {
            focus_normal_firefox()?;
            sleep(Duration::from_millis(500));
            
            // Check if WhatsApp tab already exists
            if let Some(tab_id) = find_whatsapp_tab()? {
                focus_whatsapp_tab(tab_id)?;
            } else {
                launch_firefox_tab()?;
            }
        } else {
            launch_firefox_instance()?;
        }
    }
    
    Ok(())
}

fn has_normal_firefox() -> Result<bool, Box<dyn std::error::Error>> {
    let output = Command::new("hyprctl")
        .args(&["clients", "-j"])
        .output()?;
    
    let clients: Value = serde_json::from_slice(&output.stdout)?;
    
    if let Some(windows) = clients.as_array() {
        for window in windows {
            if let Some(class) = window["class"].as_str() {
                if class == "firefox" {
                    if let Some(workspace) = window["workspace"]["name"].as_str() {
                        if workspace != "special" {
                            return Ok(true);
                        }
                    }
                }
            }
        }
    }
    
    Ok(false)
}

fn has_special_firefox() -> Result<bool, Box<dyn std::error::Error>> {
    let output = Command::new("hyprctl")
        .args(&["clients", "-j"])
        .output()?;
    
    let clients: Value = serde_json::from_slice(&output.stdout)?;
    
    if let Some(windows) = clients.as_array() {
        for window in windows {
            if let Some(class) = window["class"].as_str() {
                if class == "firefox" {
                    if let Some(workspace) = window["workspace"]["name"].as_str() {
                        if workspace == "special" {
                            return Ok(true);
                        }
                    }
                }
            }
        }
    }
    
    Ok(false)
}

fn get_normal_firefox_address() -> Result<Option<String>, Box<dyn std::error::Error>> {
    let output = Command::new("hyprctl")
        .args(&["clients", "-j"])
        .output()?;
    
    let clients: Value = serde_json::from_slice(&output.stdout)?;
    
    if let Some(windows) = clients.as_array() {
        for window in windows {
            if let Some(class) = window["class"].as_str() {
                if class == "firefox" {
                    if let Some(workspace) = window["workspace"]["name"].as_str() {
                        if workspace != "special" {
                            if let Some(address) = window["address"].as_str() {
                                return Ok(Some(address.to_string()));
                            }
                        }
                    }
                }
            }
        }
    }
    
    Ok(None)
}

fn focus_normal_firefox() -> Result<(), Box<dyn std::error::Error>> {
    if let Some(address) = get_normal_firefox_address()? {
        Command::new("hyprctl")
            .args(&["dispatch", "focuswindow", &format!("address:{}", address)])
            .output()?;
    }
    Ok(())
}

fn launch_firefox_tab() -> Result<(), Box<dyn std::error::Error>> {
    Command::new("firefox")
        .env("MOZ_ENABLE_WAYLAND", "1")
        .args(&["--new-tab", "https://web.whatsapp.com"])
        .spawn()?;
    Ok(())
}

fn launch_firefox_instance() -> Result<(), Box<dyn std::error::Error>> {
    Command::new("firefox")
        .env("MOZ_ENABLE_WAYLAND", "1")
        .args(&["--new-instance", "https://web.whatsapp.com"])
        .spawn()?;
    Ok(())
}

fn get_current_workspace() -> Result<String, Box<dyn std::error::Error>> {
    let output = Command::new("hyprctl")
        .args(&["activeworkspace", "-j"])
        .output()?;
    
    let workspace: Value = serde_json::from_slice(&output.stdout)?;
    
    if let Some(name) = workspace["name"].as_str() {
        Ok(name.to_string())
    } else {
        Ok("1".to_string()) // fallback
    }
}

fn focus_special_firefox() -> Result<(), Box<dyn std::error::Error>> {
    let output = Command::new("hyprctl")
        .args(&["clients", "-j"])
        .output()?;
    
    let clients: Value = serde_json::from_slice(&output.stdout)?;
    
    if let Some(windows) = clients.as_array() {
        for window in windows {
            if let Some(class) = window["class"].as_str() {
                if class == "firefox" {
                    if let Some(workspace) = window["workspace"]["name"].as_str() {
                        if workspace == "special" {
                            if let Some(address) = window["address"].as_str() {
                                Command::new("hyprctl")
                                    .args(&["dispatch", "focuswindow", &format!("address:{}", address)])
                                    .output()?;
                                return Ok(());
                            }
                        }
                    }
                }
            }
        }
    }
    
    Ok(())
}

fn find_whatsapp_tab() -> Result<Option<String>, Box<dyn std::error::Error>> {
    // Use hyprctl to find WhatsApp window by title
    let output = Command::new("hyprctl")
        .args(&["clients", "-j"])
        .output()?;
    
    let clients: Value = serde_json::from_slice(&output.stdout)?;
    
    if let Some(windows) = clients.as_array() {
        for window in windows {
            if let Some(class) = window["class"].as_str() {
                if class == "firefox" {
                    if let Some(title) = window["title"].as_str() {
                        // Check if the title contains WhatsApp
                        if title.to_lowercase().contains("whatsapp") {
                            if let Some(address) = window["address"].as_str() {
                                return Ok(Some(address.to_string()));
                            }
                        }
                    }
                }
            }
        }
    }
    
    Ok(None)
}

fn focus_whatsapp_tab(address: String) -> Result<(), Box<dyn std::error::Error>> {
    // Use hyprctl to focus the window by address
    Command::new("hyprctl")
        .args(&["dispatch", "focuswindow", &format!("address:{}", address)])
        .output()?;
    
    Ok(())
}