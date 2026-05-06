import re

def main():
    input_file = r"C:\Users\jsnss\OneDrive\Desktop\antigravity\grovers image search\PROJECT_\verilog\raw_hashes.txt"

    output_file = "hashes.mem"
    
    with open(input_file, "r") as f:
        lines = f.readlines()
        
    with open(output_file, "w") as out:
        for line in lines:
            match = re.search(r"hash=0x([0-9A-Fa-f]+)", line)
            if match:
                out.write(match.group(1) + "\n")

if __name__ == "__main__":
    main()
