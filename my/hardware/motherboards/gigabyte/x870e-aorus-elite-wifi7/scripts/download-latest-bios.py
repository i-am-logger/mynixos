#!/usr/bin/env python3
"""
BIOS Downloader for Gigabyte X870E AORUS Elite WiFi7

This script uses Selenium to navigate Gigabyte's website and download the latest BIOS.
Gigabyte's website uses JavaScript and blocks automated requests, so we need a real browser.

Usage:
    python download-latest-bios.py [--output-dir DIR] [--headless]

Requirements:
    - Python 3.x
    - selenium
    - chromium or firefox
"""

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path
from typing import Optional, Dict, List

try:
    from selenium import webdriver
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC
    from selenium.webdriver.chrome.options import Options as ChromeOptions
    from selenium.webdriver.firefox.options import Options as FirefoxOptions
except ImportError:
    print("Error: Selenium is not installed.")
    print("Install with: pip install selenium")
    print("Or with Nix: nix-shell -p python3Packages.selenium chromium")
    sys.exit(1)


class GigabyteBiosDownloader:
    """Download BIOS from Gigabyte's website using Selenium."""
    
    MOTHERBOARD = "X870E AORUS ELITE WIFI7"
    SUPPORT_URL = "https://www.gigabyte.com/Motherboard/X870E-AORUS-ELITE-WIFI7-rev-10/support#support-dl-bios"
    
    def __init__(self, output_dir: Path, headless: bool = False, browser: str = "chrome"):
        self.output_dir = output_dir
        self.headless = headless
        self.browser = browser
        self.driver = None
        
    def setup_driver(self):
        """Initialize the Selenium WebDriver."""
        print(f"Setting up {self.browser} driver...")
        
        if self.browser == "chrome":
            options = ChromeOptions()
            if self.headless:
                options.add_argument("--headless=new")
            options.add_argument("--no-sandbox")
            options.add_argument("--disable-dev-shm-usage")
            options.add_argument("--disable-gpu")
            options.add_argument("--window-size=1920,1080")
            options.add_argument("user-agent=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36")
            
            # Set download preferences
            prefs = {
                "download.default_directory": str(self.output_dir.absolute()),
                "download.prompt_for_download": False,
                "download.directory_upgrade": True,
                "safebrowsing.enabled": False
            }
            options.add_experimental_option("prefs", prefs)
            
            try:
                self.driver = webdriver.Chrome(options=options)
            except Exception as e:
                print(f"Chrome driver failed: {e}")
                print("Trying with chromium...")
                self.driver = webdriver.Chrome(options=options)
                
        elif self.browser == "firefox":
            options = FirefoxOptions()
            if self.headless:
                options.add_argument("--headless")
            options.set_preference("browser.download.folderList", 2)
            options.set_preference("browser.download.dir", str(self.output_dir.absolute()))
            options.set_preference("browser.download.useDownloadDir", True)
            options.set_preference("browser.helperApps.neverAsk.saveToDisk", "application/zip")
            
            self.driver = webdriver.Firefox(options=options)
        
        print(f"Driver initialized: {self.driver.capabilities['browserName']}")
    
    def get_bios_list(self) -> List[Dict[str, str]]:
        """Scrape the BIOS download list from Gigabyte's website."""
        print(f"Navigating to: {self.SUPPORT_URL}")
        self.driver.get(self.SUPPORT_URL)
        
        # Wait for page to load
        print("Waiting for page to load...")
        time.sleep(5)  # Initial wait for JavaScript
        
        try:
            # Wait for BIOS section to be visible
            WebDriverWait(self.driver, 20).until(
                EC.presence_of_element_located((By.ID, "support-dl-bios"))
            )
            print("BIOS section found")
        except Exception as e:
            print(f"Warning: Could not find BIOS section: {e}")
            print("Page source preview:")
            print(self.driver.page_source[:1000])
        
        # Try multiple selectors to find BIOS downloads
        bios_items = []
        
        selectors = [
            "//div[@id='support-dl-bios']//a[contains(@href, '.zip')]",
            "//div[contains(@class, 'download')]//a[contains(@href, 'bios')]",
            "//a[contains(@href, 'mb_bios_')]",
            "//tr[contains(@class, 'download-item')]//a",
        ]
        
        for selector in selectors:
            try:
                elements = self.driver.find_elements(By.XPATH, selector)
                if elements:
                    print(f"Found {len(elements)} items with selector: {selector}")
                    for elem in elements:
                        href = elem.get_attribute("href")
                        text = elem.text.strip()
                        if href and ".zip" in href.lower():
                            # Extract version from href or text
                            version_match = re.search(r'[fF](\d+[a-z]?)', href + text)
                            version = version_match.group(0) if version_match else "unknown"
                            
                            bios_items.append({
                                "version": version,
                                "url": href,
                                "text": text,
                                "element": elem
                            })
                    break
            except Exception as e:
                print(f"Selector failed: {selector} - {e}")
                continue
        
        if not bios_items:
            print("\nCould not find BIOS downloads automatically.")
            print("Saving page screenshot for debugging...")
            screenshot_path = self.output_dir / "gigabyte_page_debug.png"
            self.driver.save_screenshot(str(screenshot_path))
            print(f"Screenshot saved: {screenshot_path}")
            
            print("\nSaving page HTML for debugging...")
            html_path = self.output_dir / "gigabyte_page_debug.html"
            html_path.write_text(self.driver.page_source)
            print(f"HTML saved: {html_path}")
        
        return bios_items
    
    def download_bios(self, bios_item: Dict[str, str]) -> Optional[Path]:
        """Download a specific BIOS file."""
        print(f"\nDownloading BIOS {bios_item['version']}...")
        print(f"URL: {bios_item['url']}")
        
        # Click the download link
        try:
            bios_item['element'].click()
            print("Download initiated...")
            
            # Wait for download to complete (check for .zip file)
            timeout = 120  # 2 minutes timeout
            start_time = time.time()
            
            while time.time() - start_time < timeout:
                zip_files = list(self.output_dir.glob("*.zip"))
                # Filter out partial downloads
                complete_files = [f for f in zip_files if not str(f).endswith(".part")]
                
                if complete_files:
                    # Check if file is still growing
                    latest_file = max(complete_files, key=lambda p: p.stat().st_mtime)
                    size1 = latest_file.stat().st_size
                    time.sleep(2)
                    size2 = latest_file.stat().st_size
                    
                    if size1 == size2 and size1 > 0:
                        print(f"Download complete: {latest_file.name}")
                        return latest_file
                
                time.sleep(1)
            
            print("Download timeout!")
            return None
            
        except Exception as e:
            print(f"Download failed: {e}")
            return None
    
    def get_current_bios_version(self) -> str:
        """Get currently installed BIOS version from system."""
        try:
            with open("/sys/class/dmi/id/bios_version", "r") as f:
                return f.read().strip()
        except Exception:
            return "Unknown"
    
    def run(self) -> bool:
        """Main execution flow."""
        try:
            current_version = self.get_current_bios_version()
            print(f"Current BIOS version: {current_version}")
            print(f"Motherboard: {self.MOTHERBOARD}")
            print(f"Output directory: {self.output_dir}")
            print()
            
            self.setup_driver()
            
            bios_list = self.get_bios_list()
            
            if not bios_list:
                print("\n❌ Could not find BIOS downloads on Gigabyte's website.")
                print("\nManual steps:")
                print(f"1. Visit: {self.SUPPORT_URL}")
                print("2. Look for BIOS downloads section")
                print("3. Download the latest BIOS manually")
                print(f"4. Save to: {self.output_dir}")
                return False
            
            print(f"\n✅ Found {len(bios_list)} BIOS version(s):\n")
            for i, item in enumerate(bios_list, 1):
                print(f"{i}. Version {item['version']}: {item['text']}")
            
            # Download the first (latest) BIOS
            latest = bios_list[0]
            print(f"\nDownloading latest version: {latest['version']}")
            
            downloaded_file = self.download_bios(latest)
            
            if downloaded_file:
                print(f"\n✅ SUCCESS!")
                print(f"BIOS downloaded: {downloaded_file}")
                print(f"Version: {latest['version']}")
                print(f"Size: {downloaded_file.stat().st_size / 1024 / 1024:.1f} MB")
                
                # Create info file
                info_file = self.output_dir / "bios_info.json"
                info = {
                    "motherboard": self.MOTHERBOARD,
                    "current_version": current_version,
                    "downloaded_version": latest['version'],
                    "file": downloaded_file.name,
                    "url": latest['url'],
                    "download_date": time.strftime("%Y-%m-%d %H:%M:%S"),
                }
                info_file.write_text(json.dumps(info, indent=2))
                print(f"\nBIOS info saved: {info_file}")
                
                print("\n📝 Next steps:")
                print("1. Extract the ZIP file")
                print("2. Copy to USB drive (FAT32 formatted)")
                print("3. Reboot into BIOS (press Del or F2)")
                print("4. Use Q-Flash to update BIOS")
                print("5. After update, reset BIOS settings and reconfigure")
                
                return True
            else:
                print("\n❌ Download failed or timed out")
                return False
                
        except Exception as e:
            print(f"\n❌ Error: {e}")
            import traceback
            traceback.print_exc()
            return False
            
        finally:
            if self.driver:
                print("\nClosing browser...")
                self.driver.quit()


def main():
    parser = argparse.ArgumentParser(
        description="Download latest BIOS for Gigabyte X870E AORUS Elite WiFi7"
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path.home() / "Downloads" / "bios",
        help="Output directory for downloaded BIOS (default: ~/Downloads/bios)"
    )
    parser.add_argument(
        "--headless",
        action="store_true",
        help="Run browser in headless mode (no GUI)"
    )
    parser.add_argument(
        "--browser",
        choices=["chrome", "firefox"],
        default="chrome",
        help="Browser to use (default: chrome)"
    )
    
    args = parser.parse_args()
    
    # Create output directory
    args.output_dir.mkdir(parents=True, exist_ok=True)
    
    print("=" * 70)
    print("Gigabyte X870E AORUS Elite WiFi7 - BIOS Downloader")
    print("=" * 70)
    print()
    
    downloader = GigabyteBiosDownloader(
        output_dir=args.output_dir,
        headless=args.headless,
        browser=args.browser
    )
    
    success = downloader.run()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
