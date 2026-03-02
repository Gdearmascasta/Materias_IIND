import sys
import os
import json
import nbformat
from nbconvert import HTMLExporter
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QLineEdit, QPushButton, QFrame, QScrollArea, QSplitter
)
from PyQt6.QtWebEngineWidgets import QWebEngineView
from PyQt6.QtCore import Qt, QFileSystemWatcher, QTimer, QUrl
from PyQt6.QtGui import QFont, QIcon, QColor

class NotebookProcessor:
    def __init__(self, filepath):
        self.filepath = filepath
        self.html_content = ""
        self.kpis = {
            "total_clients": 0,
            "active_routes": 0,
            "distances": []
        }
        
    def process_notebook(self):
        try:
            with open(self.filepath, 'r', encoding='utf-8') as f:
                nb_content = f.read()
                
            # Parse to find the last map
            notebook = nbformat.reads(nb_content, as_version=4)
            
            last_map_idx = -1
            map_html_str = ""
            for i, cell in enumerate(notebook.cells):
                if cell.cell_type == 'code':
                    for output in cell.outputs:
                        if output.output_type in ('display_data', 'execute_result'):
                            html = output.get('data', {}).get('text/html', '')
                            if isinstance(html, list):
                                html = ''.join(html)
                            if 'Make this Notebook Trusted' in html or 'folium' in html.lower() or 'leaflet' in html.lower() or 'L.circleMarker' in html:
                                last_map_idx = i
                                map_html_str = html
            
            # Extract KPIs using both notebook text and last map html
            nb_json = json.loads(nb_content)
            self._extract_kpis(nb_json, map_html_str)
            
            if last_map_idx != -1:
                # Keep only the last map cell for the UI
                notebook.cells = [notebook.cells[last_map_idx]]
            
            # Convert to HTML
            html_exporter = HTMLExporter()
            html_exporter.exclude_input = True # Optional: hide code cells
            html_exporter.theme = 'dark'
            
            (body, resources) = html_exporter.from_notebook_node(notebook)
            
            # Add custom CSS to the HTML to ensure dark mode and better map fitting
            custom_css = """
            <style>
                body {
                    background-color: #1a1a1a;
                    color: #e0e0e0;
                    margin: 0;
                    padding: 10px;
                }
                .jp-RenderedHTMLCommon {
                    color: #e0e0e0;
                }
                /* Attempt to make folium map responsive */
                iframe {
                    width: 100% !important;
                    height: 80vh !important;
                    border: none;
                    border-radius: 8px;
                }
            </style>
            """
            self.html_content = custom_css + body
            
            return True
        except Exception as e:
            print(f"Error processing notebook: {e}")
            self.html_content = f"<h2>Error loading notebook: {e}</h2>"
            return False
            
    def _extract_kpis(self, nb, map_html=""):
        self.kpis["distances"] = []
        self.kpis["distances_dict"] = {}
        self.kpis["total_distance"] = 0.0
        
        # 1. Extract distances from text console outputs
        temp_dist_dict = {}
        for cell in nb.get('cells', []):
            if cell.get('cell_type') == 'code':
                for output in cell.get('outputs', []):
                    if output.get('output_type') == 'stream':
                        text = "".join(output.get('text', []))
                        
                        if "Distancia real:" in text:
                            lines = text.split('\n')
                            current_vehicle = ""
                            for line in lines:
                                if "Veh" in line and ("Rojo" in line or "Verde" in line or "Azul" in line or "ículo" in line or "culo" in line):
                                    # Normalize vehicle name extraction to avoid encoding issues
                                    current_vehicle = line.strip().split()[-1] if " " in line.strip() else line.strip()
                                elif "Distancia real:" in line:
                                    dist_str = line.split(':')[-1].strip()
                                    if current_vehicle:
                                        temp_dist_dict[current_vehicle] = dist_str
                                        
        # Compile unique distances and sum them up
        for vehicle, dist_str in temp_dist_dict.items():
            self.kpis["distances"].append(f"{vehicle}: {dist_str}")
            self.kpis["distances_dict"][vehicle] = dist_str
            try:
                dist_val = float(dist_str.lower().replace("km", "").strip())
                self.kpis["total_distance"] += dist_val
            except ValueError:
                pass
                                        
        # 2. Extract points (clients) and counts (routes) directly from the last map HTML
        if map_html:
            self.kpis["total_clients"] = map_html.count('L.circleMarker')
            self.kpis["active_routes"] = map_html.count('L.polyline')
        else:
            self.kpis["total_clients"] = 0
            self.kpis["active_routes"] = len(self.kpis["distances"])


class DashboardWindow(QMainWindow):
    def __init__(self, notebook_path):
        super().__init__()
        self.notebook_path = notebook_path
        self.processor = NotebookProcessor(notebook_path)
        
        self.setWindowTitle("Logistics Control Center")
        self.setGeometry(100, 100, 1400, 900)
        
        self.init_ui()
        self.setup_file_watcher()
        self.load_data()
        
    def init_ui(self):
        # Main Widget and Layout
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)
        
        # --- Top Bar (Search) ---
        top_bar = QFrame()
        top_bar.setObjectName("TopBar")
        top_bar.setFixedHeight(70)
        top_layout = QHBoxLayout(top_bar)
        top_layout.setContentsMargins(20, 10, 20, 10)
        
        title_label = QLabel("LOGISTICS HUB")
        title_label.setObjectName("AppTitle")
        title_label.setFont(QFont("Segoe UI", 16, QFont.Weight.Bold))
        
        reload_btn = QPushButton("🔄 Force Reload")
        reload_btn.setObjectName("SecondaryButton")
        reload_btn.clicked.connect(self.load_data)
        
        top_layout.addWidget(title_label)
        top_layout.addStretch()
        top_layout.addWidget(reload_btn)
        
        main_layout.addWidget(top_bar)
        
        # --- Content Area (Splitter) ---
        splitter = QSplitter(Qt.Orientation.Horizontal)
        main_layout.addWidget(splitter)
        
        # 1. Sidebar (KPIs)
        self.sidebar = QScrollArea()
        self.sidebar.setObjectName("Sidebar")
        self.sidebar.setWidgetResizable(True)
        self.sidebar.setMinimumWidth(300)
        self.sidebar.setMaximumWidth(400)
        
        sidebar_content = QWidget()
        self.sidebar_layout = QVBoxLayout(sidebar_content)
        self.sidebar_layout.setAlignment(Qt.AlignmentFlag.AlignTop)
        self.sidebar_layout.setSpacing(20)
        self.sidebar_layout.setContentsMargins(20, 30, 20, 30)
        
        # KPI Widgets will be populated later
        self.kpi_clients_label = self._create_kpi_card("Total Customers", "0")
        self.kpi_routes_label = self._create_kpi_card("Active Routes", "0")
        self.kpi_total_dist_label = self._create_kpi_card("Total Distance", "0.00 km")
        
        self.sidebar_layout.addWidget(self.kpi_clients_label)
        self.sidebar_layout.addWidget(self.kpi_routes_label)
        self.sidebar_layout.addWidget(self.kpi_total_dist_label)
        
        self.sidebar.setWidget(sidebar_content)
        splitter.addWidget(self.sidebar)
        
        # 2. Main View (WebEngine)
        self.web_view = QWebEngineView()
        self.web_view.setObjectName("WebView")
        splitter.addWidget(self.web_view)
        
        # Set splitter sizes (20% sidebar, 80% map)
        splitter.setSizes([300, 1100])
        
    def _create_kpi_card(self, title, initial_value):
        card = QFrame()
        card.setObjectName("KpiCard")
        layout = QVBoxLayout(card)
        layout.setContentsMargins(15, 15, 15, 15)
        
        title_lbl = QLabel(title)
        title_lbl.setObjectName("KpiTitle")
        
        val_lbl = QLabel(initial_value)
        val_lbl.setObjectName("KpiValue")
        val_lbl.setWordWrap(True)
        
        layout.addWidget(title_lbl)
        layout.addWidget(val_lbl)
        
        # Store a reference to the value label on the card widget itself
        # for easy updating later
        card.value_label = val_lbl 
        return card

    def _create_route_distance_cards(self):
        # Clear existing route cards if any
        if hasattr(self, 'route_cards_container') and self.route_cards_container is not None:
            self.route_cards_container.deleteLater()
            
        self.route_cards_container = QWidget()
        layout = QVBoxLayout(self.route_cards_container)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(10)
        
        self.route_labels = {}
        for vehicle, dist in self.processor.kpis.get("distances_dict", {}).items():
            card = self._create_kpi_card(f"Distance {vehicle}", dist)
            layout.addWidget(card)
            self.route_labels[vehicle] = card
            
        self.sidebar_layout.addWidget(self.route_cards_container)
        
    def load_data(self):
        print("Loading/Reloading data...")
        if self.processor.process_notebook():
            # Update WebView
            self.web_view.setHtml(self.processor.html_content)
            
            # Update KPIs
            self.kpi_clients_label.value_label.setText(str(self.processor.kpis["total_clients"]))
            self.kpi_routes_label.value_label.setText(str(self.processor.kpis["active_routes"]))
            
            # Update total distance
            total_dist = f"{self.processor.kpis.get('total_distance', 0.0):.2f} km"
            self.kpi_total_dist_label.value_label.setText(total_dist)
            
            # Create/Update individual route distance cards
            self._create_route_distance_cards()
            
            print("Data loaded successfully.")
            
    def setup_file_watcher(self):
        self.watcher = QFileSystemWatcher(self)
        self.watcher.addPath(self.notebook_path)
        self.watcher.fileChanged.connect(self.on_file_changed)
        
        # Timer to debounce rapid saves
        self.reload_timer = QTimer(self)
        self.reload_timer.setSingleShot(True)
        self.reload_timer.timeout.connect(self.load_data)
        
    def on_file_changed(self, path):
        print(f"File {path} changed. Scheduling reload...")
        # Debounce: wait 1000ms before reloading to avoid partial reads
        self.reload_timer.start(1000)

def apply_stylesheet(app):
    dark_style = """
    QMainWindow {
        background-color: #121212;
    }
    
    QFrame#TopBar {
        background-color: #1E1E1E;
        border-bottom: 2px solid #2D2D2D;
    }
    
    QLabel#AppTitle {
        color: #FF5722;
        letter-spacing: 2px;
    }
    
    QLineEdit#SearchBar {
        background-color: #2D2D2D;
        color: #FFFFFF;
        border: 1px solid #404040;
        border-radius: 4px;
        padding: 8px 15px;
        font-size: 14px;
    }
    QLineEdit#SearchBar:focus {
        border: 1px solid #FF5722;
    }
    
    QPushButton {
        padding: 8px 20px;
        font-weight: bold;
        border-radius: 4px;
        font-size: 14px;
    }
    
    QPushButton#PrimaryButton {
        background-color: #FF5722;
        color: white;
        border: none;
    }
    QPushButton#PrimaryButton:hover {
        background-color: #F4511E;
    }
    QPushButton#PrimaryButton:pressed {
        background-color: #E64A19;
    }
    
    QPushButton#SecondaryButton {
        background-color: #333333;
        color: #E0E0E0;
        border: 1px solid #404040;
    }
    QPushButton#SecondaryButton:hover {
        background-color: #404040;
    }
    
    QScrollArea#Sidebar {
        background-color: #1A1A1A;
        border: none;
        border-right: 1px solid #2D2D2D;
    }
    
    QScrollArea#Sidebar QWidget {
        background-color: #1A1A1A;
    }
    
    QFrame#KpiCard {
        background-color: #242424;
        border-radius: 8px;
        border-left: 4px solid #4CAF50;
    }
    
    QLabel#KpiTitle {
        color: #9E9E9E;
        font-size: 13px;
        font-weight: bold;
        text-transform: uppercase;
    }
    
    QLabel#KpiValue {
        color: #FFFFFF;
        font-size: 24px;
        font-weight: bold;
        margin-top: 5px;
    }
    
    /* Splitter custom styling */
    QSplitter::handle {
        background-color: #2D2D2D;
    }
    """
    app.setStyleSheet(dark_style)

if __name__ == "__main__":
    app = QApplication(sys.argv)
    apply_stylesheet(app)
    
    # Path to the notebook
    nb_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "TallerDYT.ipynb")
    
    window = DashboardWindow(nb_path)
    window.show()
    
    sys.exit(app.exec())
