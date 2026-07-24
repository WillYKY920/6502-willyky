import tkinter as tk
from tkinter import filedialog, messagebox, ttk
import mido
import os

class Midi2VoiceSequentialApp:
    def __init__(self, root):
        self.root = root
        self.root.title("6502 Dual-Voice Sequential Converter")
        self.root.geometry("540x480")
        self.root.resizable(False, False)
        
        style = ttk.Style()
        style.theme_use('clam')
        
        # Application Variables
        self.midi_path = tk.StringVar()
        self.output_path = tk.StringVar()
        self.start_time_str = tk.StringVar(value="0:00")
        self.end_time_str = tk.StringVar(value="1:30")
        self.start_line = tk.IntVar(value=1000)
        self.line_inc = tk.IntVar(value=10)
        self.speed_factor = tk.DoubleVar(value=1.0)  # Speed Multiplier Variable
        
        self.create_widgets()
        
    def create_widgets(self):
        padding_opts = {'padx': 10, 'pady': 6}
        
        file_frame = ttk.LabelFrame(self.root, text=" File Selection ")
        file_frame.pack(fill="x", **padding_opts)
        
        ttk.Label(file_frame, text="MIDI File:").grid(row=0, column=0, sticky="w", padx=5, pady=5)
        ttk.Entry(file_frame, textvariable=self.midi_path, width=42).grid(row=0, column=1, padx=5, pady=5)
        ttk.Button(file_frame, text="Browse...", command=self.browse_midi).grid(row=0, column=2, padx=5, pady=5)
        
        ttk.Label(file_frame, text="Save BASIC As:").grid(row=1, column=0, sticky="w", padx=5, pady=5)
        ttk.Entry(file_frame, textvariable=self.output_path, width=42).grid(row=1, column=1, padx=5, pady=5)
        ttk.Button(file_frame, text="Browse...", command=self.browse_output).grid(row=1, column=2, padx=5, pady=5)
        
        time_frame = ttk.LabelFrame(self.root, text=" Track Slicer Settings ")
        time_frame.pack(fill="x", **padding_opts)
        
        ttk.Label(time_frame, text="Start Time (MM:SS or Sec):").grid(row=0, column=0, sticky="w", padx=5, pady=5)
        ttk.Entry(time_frame, textvariable=self.start_time_str, width=12).grid(row=0, column=1, sticky="w", padx=5, pady=5)
        
        ttk.Label(time_frame, text="End Time (MM:SS or Sec):").grid(row=0, column=2, sticky="w", padx=15, pady=5)
        ttk.Entry(time_frame, textvariable=self.end_time_str, width=12).grid(row=0, column=3, sticky="w", padx=5, pady=5)
        
        settings_frame = ttk.LabelFrame(self.root, text=" MS BASIC Line & Speed Formatting ")
        settings_frame.pack(fill="x", **padding_opts)
        
        ttk.Label(settings_frame, text="Data Start Line:").grid(row=0, column=0, sticky="w", padx=5, pady=5)
        ttk.Entry(settings_frame, textvariable=self.start_line, width=10).grid(row=0, column=1, sticky="w", padx=5, pady=5)
        
        ttk.Label(settings_frame, text="Line Increment:").grid(row=0, column=2, sticky="w", padx=15, pady=5)
        ttk.Entry(settings_frame, textvariable=self.line_inc, width=10).grid(row=0, column=3, sticky="w", padx=5, pady=5)

        ttk.Label(settings_frame, text="Speed Multiplier:").grid(row=1, column=0, sticky="w", padx=5, pady=5)
        ttk.Entry(settings_frame, textvariable=self.speed_factor, width=10).grid(row=1, column=1, sticky="w", padx=5, pady=5)
        ttk.Label(settings_frame, text="(e.g., 2.0 = 2x speed, 0.5 = 0.5x speed)", foreground="gray").grid(row=1, column=2, columnspan=2, sticky="w", padx=5, pady=5)
        
        info_text = (
            "ENGINE MODE: SEQUENTIAL STREAM (ANTI-JITTER)\n"
            "Streams raw notes directly into the SYNTH routine sequentially.\n"
            "Format: DATA Voice1_uS, Voice2_uS, Duration"
        )
        ttk.Label(self.root, text=info_text, justify="center", foreground="darkblue", font=("Arial", 9, "bold")).pack(pady=5)
        
        self.convert_btn = ttk.Button(self.root, text="COMPILE TO SEQUENTIAL BASIC DATA", command=self.process_conversion)
        self.convert_btn.pack(pady=10, ipadx=20, ipady=5)

    def browse_midi(self):
        filename = filedialog.askopenfilename(filetypes=[("MIDI Files", "*.mid *.midi")])
        if filename:
            self.midi_path.set(filename)
            base, _ = os.path.splitext(filename)
            self.output_path.set(base + "_sequential.txt")
            
    def browse_output(self):
        filename = filedialog.asksaveasfilename(defaultextension=".txt", filetypes=[("Text Files", "*.txt")])
        if filename:
            self.output_path.set(filename)

    def parse_time_to_seconds(self, time_str):
        try:
            time_str = time_str.strip()
            if ":" in time_str:
                parts = time_str.split(":")
                minutes = int(parts[0])
                seconds = float(parts[1])
                return (minutes * 60) + seconds
            else:
                return float(time_str)
        except (ValueError, IndexError):
            return None
            
    def process_conversion(self):
        m_path = self.midi_path.get()
        o_path = self.output_path.get()
        
        start_sec = self.parse_time_to_seconds(self.start_time_str.get())
        end_sec = self.parse_time_to_seconds(self.end_time_str.get())
        
        try:
            speed = float(self.speed_factor.get())
            if speed <= 0:
                raise ValueError
        except ValueError:
            messagebox.showerror("Error", "Speed Multiplier must be a positive number (e.g., 1.0, 1.5, 0.8).")
            return
        
        if not m_path or not os.path.exists(m_path):
            messagebox.showerror("Error", "Please select a valid input MIDI file.")
            return
        if not o_path:
            messagebox.showerror("Error", "Please specify an output text path.")
            return
        if start_sec is None or end_sec is None or start_sec >= end_sec:
            messagebox.showerror("Error", "Invalid Time settings.")
            return
            
        try:
            mid = mido.MidiFile(m_path)
        except Exception as e:
            messagebox.showerror("MIDI Error", f"Could not read MIDI file:\n{e}")
            return

        timeline = []
        active_notes = []
        accumulated_time = 0.0
        
        for msg in mid:
            accumulated_time += msg.time
            if msg.time > 0 and accumulated_time > 0.002:
                timeline.append((accumulated_time, list(active_notes)))
                accumulated_time = 0.0
            if msg.is_meta:
                continue
            if msg.type == 'note_on' and msg.velocity > 0:
                if msg.note not in active_notes:
                    active_notes.append(msg.note)
            elif msg.type == 'note_off' or (msg.type == 'note_on' and msg.velocity == 0):
                if msg.note in active_notes:
                    active_notes.remove(msg.note)

        if accumulated_time > 0.002:
            timeline.append((accumulated_time, list(active_notes)))

        # Slicing
        sliced_timeline = []
        timeline_cursor = 0.0
        for dur_sec, notes in timeline:
            event_start = timeline_cursor
            event_end = timeline_cursor + dur_sec
            timeline_cursor = event_end
            if event_end <= start_sec:
                continue
            if event_start >= end_sec:
                break
            actual_start = max(event_start, start_sec)
            actual_end = min(event_end, end_sec)
            actual_dur = actual_end - actual_start
            if actual_dur > 0.002:
                sliced_timeline.append((actual_dur, notes))

        # Extract Voice 1 and Voice 2
        raw_events = []
        for dur_sec, notes in sliced_timeline:
            if not notes:
                raw_events.append((None, None, dur_sec))
            elif len(notes) == 1:
                raw_events.append((notes[0], None, dur_sec))
            else:
                sorted_notes = sorted(notes, reverse=True)
                raw_events.append((sorted_notes[0], sorted_notes[1], dur_sec))

        # Convert to 6502 loop metrics (approx 2.17ms per step) with Speed Adjustment
        sequential_stream = []
        for v1_note, v2_note, duration_sec in raw_events:
            # Divide duration by speed factor to scale play rate
            duration_ms = (duration_sec * 1000) / speed
            duration_val = int(round(duration_ms / 2.17))
            
            if duration_val == 0:
                continue
                
            while duration_val > 255:
                sequential_stream.append((v1_note, v2_note, 255))
                duration_val -= 255
            if duration_val > 0:
                sequential_stream.append((v1_note, v2_note, duration_val))

        if not sequential_stream:
            messagebox.showwarning("Warning", "No musical data found inside that slice window.")
            return

        # Turn sequence into string formatting elements
        data_rows = []
        for v1, v2, dur in sequential_stream:
            hp1 = 0 if v1 is None else int(round(1000000.0 / (440.0 * (2.0 ** ((v1 - 69) / 12.0))) / 2.0))
            hp2 = 0 if v2 is None else int(round(1000000.0 / (440.0 * (2.0 ** ((v2 - 69) / 12.0))) / 2.0))
            data_rows.append(f"{hp1},{hp2},{dur}")

        lines = [
            "10 REM --- MIDI PLAYER ---",
            "20 READ V1, V2, DU",
            "30 IF V1 = -1 THEN END",
            "40 SYNTH V1, V2, DU",
            "50 GOTO 20"
        ]
        
        line_num = self.start_line.get()
        lines.append(f"{line_num} REM --- RAW SEQUENTIAL AUDIO STREAM ---")
        line_num += self.line_inc.get()
        
        # Group 4 frames per line
        for i in range(0, len(data_rows), 4):
            chunk = data_rows[i:i+4]
            chunk_str = ",".join(chunk)
            lines.append(f"{line_num} DATA {chunk_str}")
            line_num += self.line_inc.get()

        # Add stop sentinel
        lines.append(f"{line_num} DATA -1,0,0")

        try:
            with open(o_path, 'w') as f:
                f.write('\n'.join(lines) + '\n')
            messagebox.showinfo("Success", f"Sequential Export Complete!\nTotal frames generated: {len(sequential_stream)}")
        except Exception as e:
            messagebox.showerror("Write Error", f"Could not save file:\n{e}") 

if __name__ == "__main__":
    root = tk.Tk()
    app = Midi2VoiceSequentialApp(root)
    root.mainloop()