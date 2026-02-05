import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from matplotlib.lines import Line2D

# Set font to Times New Roman for IEEE paper
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.serif'] = ['Times New Roman']

# 1. Load Data
nocrouter_df = pd.read_csv("nocrouter_results.csv")
ranc_df = pd.read_csv("ranc_results.csv")
ravenoc_df = pd.read_csv("ravenoc_results.csv")

nocrouter_df['Router'] = 'NoCRouter'
ranc_df['Router'] = 'RANC'
ravenoc_df['Router'] = 'RaveNoC'

all_data = pd.concat([nocrouter_df, ranc_df, ravenoc_df], ignore_index=True)

# 2. Parsing Helpers
def parse_load(tag):
    if 'saturated' in tag: return 1.0
    if 'heavy' in tag: return 0.5
    if 'medium' in tag: return 0.25
    if 'light' in tag: return 0.125
    return None

def parse_benchmark_pattern(tag):
    if not tag.startswith('benchmark_'): return None
    if 'uniform' in tag: return 'Uniform'
    if 'hotspot' in tag: return 'Hotspot'
    if 'transpose' in tag: return 'Transpose'
    return None

def parse_hotspot_degree(tag):
    if not tag.startswith('hotspot_'): return None
    base = tag.split('_light')[0].split('_medium')[0].split('_heavy')[0].split('_saturated')[0]
    mapping = {
        'hotspot_north': 1, 'hotspot_north_south': 2,
        'hotspot_north_south_east': 3, 'hotspot_north_south_east_west': 4
    }
    return mapping.get(base)

def get_annotation_params(i, y_max):
    """Determine annotation position (ha, va, dx, dy) based on graph index."""
    if i == 1:   # Top Left
        ha, va = 'right', 'bottom'
        dx, dy = -0.0111, y_max * 0.0111
    elif i == 2: # Top Right
        ha, va = 'left', 'bottom'
        dx, dy = 0.0111, y_max * 0.0111
    elif i == 3: # Bottom Left
        ha, va = 'right', 'top'
        dx, dy = -0.0111, -y_max * 0.0111
    else:        # Bottom Right
        ha, va = 'left', 'top'
        dx, dy = 0.0111, -y_max * 0.0111
    return ha, va, dx, dy

all_data['Load'] = all_data['tag'].apply(parse_load)
all_data['Bench_Pattern'] = all_data['tag'].apply(parse_benchmark_pattern)
all_data['Hotspot_Degree'] = all_data['tag'].apply(parse_hotspot_degree)

# 3. Plotting Configuration
TRAFFIC_COLORS = {
    'Uniform':   '#EDE569', # Light yellow
    'Transpose': '#3DAAB8', # Medium blue
    'Hotspot':   '#215BA3'  # Dark blue
}

TRAFFIC_STYLES = {
    'Uniform':   {'marker': 'o', 'markersize': 6},
    'Transpose': {'marker': 'o', 'markersize': 9, 'markerfacecolor': 'none', 'markeredgewidth': 1.5},
    'Hotspot':   {'marker': 'x', 'markersize': 8, 'markeredgewidth': 1.5}
}

DEGREE_COLORS = {
    1: '#EDE569', # Light yellow
    2: '#6EC791', # Light green
    3: '#3DAAB8', # Medium blue
    4: '#215BA3'  # Dark blue
}

# Font sizes
# FONTSIZE_TITLE = 12
# FONTSIZE_LABEL = 11
# FONTSIZE_ROUTER = 13
# FONTSIZE_TICK = 10
# FONTSIZE_ROUTER = 18
# FONTSIZE_TITLE = 16
# FONTSIZE_LABEL = 15
# FONTSIZE_TICK = 14
# FONTSIZE_LOSS = 12
FONTSIZE_ROUTER = 20
FONTSIZE_TITLE = 18
FONTSIZE_LABEL = 17
FONTSIZE_TICK = 16
FONTSIZE_LOSS = 14
FONTSIZE_HEATMAP_ANNOT = FONTSIZE_TICK
FONTSIZE_HEATMAP_CBAR = FONTSIZE_TICK

# Testbench paramters

def plot_router_row(router_name, df, axes_row, is_first_row=False, is_last_row=False):
    router_data = df[df['Router'] == router_name]
    
    # --- Plot 1: Traffic Throughput (Normalized) ---
    ax = axes_row[0]
    ax.set_aspect('auto') # Ensure we can control it if needed, but 'equal' isn't usually right for different unit axes
    if is_first_row:
        ax.set_title('Avg. Packet Throughput of\nDifferent Traffic Patterns', fontsize=FONTSIZE_TITLE)
    # ax.set_ylabel(f'{router_name}\nPackets/Cycle', fontsize=FONTSIZE_ROUTER, fontweight='bold')
    # Combined y-label with different styles for each line
    # We clear the default ylabel and use two text objects for precise styling and stacking
    ax.set_ylabel('') 
    # ax.set_ylabel('', labelpad=40) 
    ax.text(-0.225, 0.48, router_name, transform=ax.transAxes, rotation=90,
            fontsize=FONTSIZE_ROUTER, fontweight='bold', ha='center', va='center')
    ax.text(-0.13, 0.48, 'Normalized Throughput', transform=ax.transAxes, rotation=90,
            fontsize=FONTSIZE_LABEL, fontweight='normal', ha='center', va='center')
    ax.set_xlim(0, 1.1)
    ax.set_ylim(0, 5)
    ax.set_box_aspect(1) # Make the plot box square
    ax.tick_params(labelsize=FONTSIZE_TICK)
    
    bench_data = router_data.dropna(subset=['Bench_Pattern'])
    for i, t_type in enumerate(['Uniform', 'Hotspot', 'Transpose']):
        subset = bench_data[bench_data['Bench_Pattern'] == t_type].sort_values('Load')
        if not subset.empty:
            style = TRAFFIC_STYLES.get(t_type, {'marker': 'o'})
            color = TRAFFIC_COLORS[t_type]
            # Normalize throughput by dividing by injection rate (Load)
            normalized_throughput = subset['throughput_packets_per_cycle'] / subset['Load']
            ax.plot(subset['Load'], normalized_throughput, 
                    color=color, label=t_type, **style)
            
            # Determine annotation position
            ha, va, dx, dy = get_annotation_params(i, 1800)

            # Loss Annotation
            for idx, row in subset.iterrows():
                if row['loss_percent'] > 0:
                    norm_tput = row['throughput_packets_per_cycle'] / row['Load']
                    ax.text(row['Load'] + dx, norm_tput + dy, 
                            f"{row['loss_percent']:.1f}%", ha=ha, va=va, 
                            fontsize=FONTSIZE_LOSS, color=color,
                            bbox=dict(facecolor='white', alpha=0.5, edgecolor='none', pad=1))
    
    ax.grid(axis='y', alpha=0.5)
    if is_last_row:
        ax.set_xlabel('Injection Rate', fontsize=FONTSIZE_LABEL)

    # --- Plot 2: Traffic Latency ---
    ax = axes_row[1]
    if is_first_row:
        ax.set_title('Avg. Packet Latency of\nDifferent Traffic Patterns', fontsize=FONTSIZE_TITLE)
    ax.set_ylabel('Latency [cycles]', fontsize=FONTSIZE_LABEL)
    ax.set_xlim(0, 1.1)
    ax.set_ylim(0, 25)
    ax.set_box_aspect(1) # Make the plot box square
    ax.tick_params(labelsize=FONTSIZE_TICK)
    
    for i, t_type in enumerate(['Uniform', 'Hotspot', 'Transpose']):
        subset = bench_data[bench_data['Bench_Pattern'] == t_type].sort_values('Load')
        if not subset.empty:
            style = TRAFFIC_STYLES.get(t_type, {'marker': 'o'})
            color = TRAFFIC_COLORS[t_type]
            ax.plot(subset['Load'], subset['avg_latency_cycles'], 
                    color=color, **style)
            
            # Determine annotation position
            ha, va, dx, dy = get_annotation_params(i, 25)

            for _, row in subset.iterrows():
                if row['loss_percent'] > 0:
                    ax.text(row['Load'] + dx, row['avg_latency_cycles'] + dy, 
                            f"{row['loss_percent']:.1f}%", ha=ha, va=va, 
                            fontsize=FONTSIZE_LOSS, color=color,
                            bbox=dict(facecolor='white', alpha=0.5, edgecolor='none', pad=1))
    ax.grid(axis='y', alpha=0.5)
    if is_last_row:
        ax.set_xlabel('Injection Rate', fontsize=FONTSIZE_LABEL)

    # --- Plot 3: Hotspot Degree Duration ---
    ax = axes_row[2]
    if is_first_row:
        ax.set_title('Abs. Execution Time of\nDifferent Hotspot Degrees', fontsize=FONTSIZE_TITLE)
    ax.set_ylabel('Duration [cycles]', fontsize=FONTSIZE_LABEL)
    ax.set_xlim(0, 1.1)
    ax.set_ylim(0, 1300)
    ax.set_box_aspect(1) # Make the plot box square
    ax.tick_params(labelsize=FONTSIZE_TICK)
    
    hs_data = router_data.dropna(subset=['Hotspot_Degree'])
    for i, deg in enumerate([1, 2, 3, 4]):
        subset = hs_data[hs_data['Hotspot_Degree'] == deg].sort_values('Load')
        if not subset.empty:
            color = DEGREE_COLORS[deg]
            ax.plot(subset['Load'], subset['duration_cycles'], 
                    color=color, marker='o', label=f'Degree {deg}')
            
            # Determine annotation position
            ha, va, dx, dy = get_annotation_params(i, 1300)

            for _, row in subset.iterrows():
                if row['loss_percent'] > 0:
                    ax.text(row['Load'] + dx, row['duration_cycles'] + dy, 
                            f"{row['loss_percent']:.1f}%", ha=ha, va=va, 
                            fontsize=FONTSIZE_LOSS, color=color,
                            bbox=dict(facecolor='white', alpha=0.5, edgecolor='none', pad=1))
    ax.grid(axis='y', alpha=0.5)
    if is_last_row:
        ax.set_xlabel('Injection Rate', fontsize=FONTSIZE_LABEL)

    # --- OLD Plot 3: Hotspot Degree Throughput (COMMENTED OUT) ---
    # ax = axes_row[2]
    # if is_first_row:
    #     ax.set_title('Avg. Throughput of Hotspot Degrees', fontsize=FONTSIZE_TITLE)
    # ax.set_ylabel('Packets/Cycle', fontsize=FONTSIZE_LABEL)
    # ax.set_ylim(0, 1)
    # ax.set_box_aspect(1) # Make the plot box square
    # ax.tick_params(labelsize=FONTSIZE_TICK)
    # 
    # hs_data = router_data.dropna(subset=['Hotspot_Degree'])
    # for i, deg in enumerate([1, 2, 3, 4]):
    #     subset = hs_data[hs_data['Hotspot_Degree'] == deg].sort_values('Load')
    #     if not subset.empty:
    #         color = DEGREE_COLORS[deg]
    #         ax.plot(subset['Load'], subset['throughput_packets_per_cycle'], 
    #                 color=color, marker='o', label=f'Degree {deg}')
    #         
    #         # Determine annotation position
    #         ha, va, dx, dy = get_annotation_params(i, 550)
    #
    #         for _, row in subset.iterrows():
    #             if row['loss_percent'] > 0:
    #                 ax.text(row['Load'] + dx, row['throughput_packets_per_cycle'] + dy, 
    #                         f"{row['loss_percent']:.1f}%", ha=ha, va=va, 
    #                         fontsize=FONTSIZE_LOSS, color=color,
    #                         bbox=dict(facecolor='white', alpha=0.5, edgecolor='none', pad=1))
    # ax.grid(axis='y', alpha=0.5)
    # if is_last_row:
    #     ax.set_xlabel('Injection Rate', fontsize=FONTSIZE_LABEL)

    # --- Plot 4: Hotspot Degree Latency ---
    ax = axes_row[3]
    if is_first_row:
        ax.set_title('Avg. Packet Latency of\nDifferent Hotspot Degrees', fontsize=FONTSIZE_TITLE)
    ax.set_ylabel('Latency [cycles]', fontsize=FONTSIZE_LABEL)
    ax.set_xlim(0, 1.1)
    ax.set_ylim(0, 25)
    ax.set_box_aspect(1) # Make the plot box square
    ax.tick_params(labelsize=FONTSIZE_TICK)
    
    for i, deg in enumerate([1, 2, 3, 4]):
        subset = hs_data[hs_data['Hotspot_Degree'] == deg].sort_values('Load')
        if not subset.empty:
            color = DEGREE_COLORS[deg]
            ax.plot(subset['Load'], subset['avg_latency_cycles'], 
                    color=color, marker='o')
            
            # Determine annotation position
            ha, va, dx, dy = get_annotation_params(i, 25)

            for _, row in subset.iterrows():
                if row['loss_percent'] > 0:
                    ax.text(row['Load'] + dx, row['avg_latency_cycles'] + dy, 
                            f"{row['loss_percent']:.1f}%", ha=ha, va=va, 
                            fontsize=FONTSIZE_LOSS, color=color,
                            bbox=dict(facecolor='white', alpha=0.5, edgecolor='none', pad=1))
    ax.grid(axis='y', alpha=0.5)
    if is_last_row:
        ax.set_xlabel('Injection Rate', fontsize=FONTSIZE_LABEL)

    # --- Plot 5: Heatmap ---
    ax = axes_row[4]
    if is_first_row:
        ax.set_title('Avg. Port-to-Port Latency,\nSaturated Load [cycles]', fontsize=FONTSIZE_TITLE)
    t_df = router_data[router_data['tag'].str.startswith('transfer_rate_')].copy()
    
    if not t_df.empty:
        t_df['Src'] = t_df['tag'].apply(lambda x: x.split('PORT_')[1].split('_to')[0])
        t_df['Dst'] = t_df['tag'].apply(lambda x: x.split('to_PORT_')[1])
        pivot = t_df.pivot(index='Src', columns='Dst', values='avg_latency_cycles')
        pivot = pivot.reindex(index=['LOCAL','NORTH','EAST','SOUTH','WEST'], 
                              columns=['LOCAL','NORTH','EAST','SOUTH','WEST'])
        
        sns.heatmap(pivot, annot=True, fmt=".1f", cmap="YlGnBu", cbar=True, ax=ax, square=True, 
                    annot_kws={"size": FONTSIZE_HEATMAP_ANNOT},
                    cbar_kws={'shrink': 0.7})
        
        # Set colorbar tick label size
        cb = ax.collections[0].colorbar
        if cb:
            cb.ax.tick_params(labelsize=FONTSIZE_HEATMAP_CBAR)

        ax.set_xticklabels(['L','N','E','S','W'], fontsize=FONTSIZE_TICK)
        ax.set_yticklabels(['L','N','E','S','W'], rotation=0, fontsize=FONTSIZE_TICK)
        ax.set_xlabel('Egress', fontsize=FONTSIZE_LABEL)
        ax.set_ylabel('Ingress', fontsize=FONTSIZE_LABEL)

    # --- Plot 6: Stall Cycles Heatmap ---
    ax = axes_row[5]
    if is_first_row:
        ax.set_title('Stall Cycles of Hotspot\nDegrees, Saturated Load', fontsize=FONTSIZE_TITLE)
    
    # Filter for hotspot degree tests at saturated load
    hs_saturated_data = router_data[
        (router_data['Hotspot_Degree'].notna()) & 
        (router_data['tag'].str.contains('saturated'))
    ].copy()
    
    if not hs_saturated_data.empty:
        # Build the stall matrix: rows = degrees (1-4), columns = ports (L, N, E, S, W)
        stall_matrix = []
        for deg in [1, 2, 3, 4]:
            row_data = hs_saturated_data[hs_saturated_data['Hotspot_Degree'] == deg]
            if not row_data.empty:
                row = row_data.iloc[0]
                stall_matrix.append([
                    row['stall_local'],
                    row['stall_north'],
                    row['stall_east'],
                    row['stall_south'],
                    row['stall_west']
                ])
            else:
                stall_matrix.append([0, 0, 0, 0, 0])
        
        stall_df = pd.DataFrame(
            stall_matrix,
            index=['D1', 'D2', 'D3', 'D4'],
            columns=['L', 'N', 'E', 'S', 'W']
        )
        
        sns.heatmap(stall_df, annot=True, fmt=".0f", cmap="YlGnBu", cbar=True, ax=ax, square=True,
                    annot_kws={"size": FONTSIZE_HEATMAP_ANNOT},
                    cbar_kws={'shrink': 0.7})
        
        # Set colorbar tick label size
        cb = ax.collections[0].colorbar
        if cb:
            cb.ax.tick_params(labelsize=FONTSIZE_HEATMAP_CBAR)
        
        ax.set_xticklabels(['L', 'N', 'E', 'S', 'W'], fontsize=FONTSIZE_TICK)
        ax.set_yticklabels(['D1', 'D2', 'D3', 'D4'], rotation=0, fontsize=FONTSIZE_TICK)
        ax.set_xlabel('', fontsize=FONTSIZE_LABEL)
        ax.set_ylabel('', fontsize=FONTSIZE_LABEL)

# --- Main Execution ---

routers = ['NoCRouter', 'RANC', 'RaveNoC']

# Create a single figure with 3 rows and 6 columns
fig, all_axes = plt.subplots(len(routers), 6, figsize=(22, 11))

for i, router in enumerate(routers):
    plot_router_row(
        router, 
        all_data, 
        axes_row=all_axes[i], 
        is_first_row=(i == 0), 
        is_last_row=(i == len(routers) - 1)
    )

# Adjust layout to reserve space at the bottom for figure-level legends
plt.tight_layout(rect=[0, 0.055, 1, 1], h_pad=0.1)

# --- Figure-level Legends ---
# Use positions of the first-row axes to determine column group centers
first_row_axes = all_axes[0]
bbox0 = first_row_axes[0].get_position()
bbox1 = first_row_axes[1].get_position()
bbox2 = first_row_axes[2].get_position()
bbox3 = first_row_axes[3].get_position()
bbox4 = first_row_axes[4].get_position()
bbox5 = first_row_axes[5].get_position()

traffic_center_x = (bbox0.x0 + bbox1.x1) / 2.0
hotspot_center_x = (bbox2.x0 + bbox3.x1) / 2.0
heatmap_center_x = (bbox4.x0 + bbox4.x1) / 2.0
stall_center_x = (bbox5.x0 + bbox5.x1) / 2.0
legend_y = 0.012

# Traffic pattern legend (Uniform / Hotspot / Transpose)
traffic_handles = [
    Line2D([0], [0], color=TRAFFIC_COLORS['Uniform'], linestyle='-', **TRAFFIC_STYLES['Uniform']),
    Line2D([0], [0], color=TRAFFIC_COLORS['Transpose'], linestyle='-', **TRAFFIC_STYLES['Transpose']),
    Line2D([0], [0], color=TRAFFIC_COLORS['Hotspot'], linestyle='-', **TRAFFIC_STYLES['Hotspot']),
]
traffic_labels = ['Uniform', 'Transpose', 'Hotspot']

fig.legend(
    handles=traffic_handles,
    labels=traffic_labels,
    loc='lower center',
    bbox_to_anchor=(traffic_center_x, legend_y),
    ncol=3,
    fontsize=FONTSIZE_TICK
)

# Hotspot degree legend (Degree 1–4)
hotspot_handles = [
    Line2D([0], [0], color=DEGREE_COLORS[1], marker='o', linestyle='-'),
    Line2D([0], [0], color=DEGREE_COLORS[2], marker='o', linestyle='-'),
    Line2D([0], [0], color=DEGREE_COLORS[3], marker='o', linestyle='-'),
    Line2D([0], [0], color=DEGREE_COLORS[4], marker='o', linestyle='-'),
]
hotspot_labels = ['Degree 1', 'Degree 2', 'Degree 3', 'Degree 4']

fig.legend(
    handles=hotspot_handles,
    labels=hotspot_labels,
    loc='lower center',
    bbox_to_anchor=(hotspot_center_x, legend_y),
    ncol=4,
    fontsize=FONTSIZE_TICK
)

# Heatmap axis key (two lines) under the heatmap column
fig.text(
    heatmap_center_x,
    legend_y + 0.0415,
    "L: Local    N: North    E: East\nS: South    W: West",
    ha='center',
    va='center',
    fontsize=FONTSIZE_TICK,
    bbox=dict(boxstyle='round,pad=0.25', facecolor='white', edgecolor='0.4', linewidth=0.8, alpha=0.4)
)

# Stall heatmap key under the stall cycles column
fig.text(
    stall_center_x,
    legend_y + 0.0415,
    "D: Degree",
    ha='center',
    va='center',
    fontsize=FONTSIZE_TICK,
    bbox=dict(boxstyle='round,pad=0.25', facecolor='white', edgecolor='0.4', linewidth=0.8, alpha=0.4)
)

plt.savefig('combined_results.pdf', bbox_inches='tight')
plt.savefig('combined_results.png', bbox_inches='tight')
