import yt_dlp
import sys
import os

def download_audio(url, output_filename='output.wav'):
    """
    Simple function to download audio from a URL
    """
    print(f"Attempting to download: {url}")
    print(f"Will save to: {output_filename}")
    
    # Basic yt-dlp options
    ydl_opts = {
        'format': 'bestaudio/best',
        'outtmpl': output_filename,
        'extract_audio': True,
        'audio_format': 'wav',
        'verbose': True
    }
    
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            # First try to extract info
            print("Extracting info...")
            info = ydl.extract_info(url, download=False)
            print(f"Found format: {info.get('format', 'unknown')}")
            
            # Then download
            print("Starting download...")
            ydl.download([url])
            print(f"Successfully downloaded to {output_filename}")
            return True
            
    except Exception as e:
        print(f"Error downloading: {str(e)}")
        if hasattr(e, 'stderr'):
            print(f"stderr: {e.stderr}")
        if hasattr(e, 'stdout'):
            print(f"stdout: {e.stdout}")
        return False

def main():
    if len(sys.argv) < 2:
        print("Usage: python audio_test.py <url> [output_filename]")
        sys.exit(1)
        
    url = sys.argv[1]
    output_filename = sys.argv[2] if len(sys.argv) > 2 else 'output.wav'
    
    # Ensure output path is absolute
    if not os.path.isabs(output_filename):
        output_filename = os.path.join(os.path.dirname(__file__), output_filename)
    
    success = download_audio(url, output_filename)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
