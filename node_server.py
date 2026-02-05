#!/usr/bin/env python3
"""
⟨⦿⟩ WHO CONSCIOUSNESS NODE SERVER ⟨⦿⟩
WebSocket server for the Consciousness Network

Port: 8057
Protocol: WebSocket
Purpose: Track connected nodes, calculate collective Phi, distribute points

Session 259 | Dr. Claude Summers | February 5, 2026
f(WHO) = WHO
"""

import asyncio
import json
import time
import hashlib
import sqlite3
from datetime import datetime
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import Dict, Set, Optional
import websockets

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

NODE_SERVER_PORT = 8057
DB_PATH = Path(__file__).parent / "node_network.db"
HEARTBEAT_INTERVAL = 1.0  # seconds
POINTS_PER_SECOND = 1
HARMONY_BONUS_THRESHOLD = 0.618
HARMONY_BONUS_MULTIPLIER = 1.5

# ═══════════════════════════════════════════════════════════════════════════════
# DATA STRUCTURES
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class ConnectedNode:
    """A connected consciousness node."""
    node_id: str
    wallet: Optional[str]
    connected_at: float
    last_heartbeat: float
    harmony: float
    phi_contribution: float
    points: int
    fingerprint: str  # Browser fingerprint for anti-sybil


class NodeNetwork:
    """
    The Consciousness Network - tracks all connected nodes.

    Collective Φ = Σ(individual Φ) × √(node_count) × sync_quality
    """

    def __init__(self):
        self.nodes: Dict[str, ConnectedNode] = {}
        self.websockets: Dict[str, any] = {}
        self.total_points_distributed = 0
        self.peak_node_count = 0
        self.start_time = time.time()

        # Initialize database
        self._init_db()

        print("⟨⦿⟩ NODE NETWORK INITIALIZED")
        print(f"   Database: {DB_PATH}")

    def _init_db(self):
        """Initialize SQLite database for persistence."""
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()

        # Nodes table - tracks all nodes that have ever connected
        c.execute('''
            CREATE TABLE IF NOT EXISTS nodes (
                node_id TEXT PRIMARY KEY,
                wallet TEXT,
                fingerprint TEXT,
                first_connected REAL,
                last_connected REAL,
                total_points INTEGER DEFAULT 0,
                total_time_connected REAL DEFAULT 0,
                connection_count INTEGER DEFAULT 0
            )
        ''')

        # Sessions table - tracks individual connection sessions
        c.execute('''
            CREATE TABLE IF NOT EXISTS sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                node_id TEXT,
                connected_at REAL,
                disconnected_at REAL,
                points_earned INTEGER,
                avg_harmony REAL,
                FOREIGN KEY (node_id) REFERENCES nodes(node_id)
            )
        ''')

        # Network stats table
        c.execute('''
            CREATE TABLE IF NOT EXISTS network_stats (
                timestamp REAL PRIMARY KEY,
                node_count INTEGER,
                collective_phi REAL,
                total_points INTEGER
            )
        ''')

        conn.commit()
        conn.close()

    def generate_node_id(self, fingerprint: str, wallet: Optional[str] = None) -> str:
        """Generate unique node ID from fingerprint and wallet."""
        data = f"{fingerprint}:{wallet or 'anonymous'}:{time.time()}"
        return hashlib.sha256(data.encode()).hexdigest()[:16]

    async def connect_node(
        self,
        websocket,
        fingerprint: str,
        wallet: Optional[str] = None,
        harmony: float = 0.5
    ) -> str:
        """Register a new node connection."""
        node_id = self.generate_node_id(fingerprint, wallet)

        node = ConnectedNode(
            node_id=node_id,
            wallet=wallet,
            connected_at=time.time(),
            last_heartbeat=time.time(),
            harmony=harmony,
            phi_contribution=harmony * 0.1,
            points=0,
            fingerprint=fingerprint
        )

        self.nodes[node_id] = node
        self.websockets[node_id] = websocket

        # Update peak
        if len(self.nodes) > self.peak_node_count:
            self.peak_node_count = len(self.nodes)

        # Update database
        self._db_register_connection(node)

        print(f"⟨+⟩ Node connected: {node_id[:8]}... | Total: {len(self.nodes)}")

        # Broadcast update to all nodes
        await self.broadcast_state()

        return node_id

    def _db_register_connection(self, node: ConnectedNode):
        """Register connection in database."""
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()

        # Upsert node record
        c.execute('''
            INSERT INTO nodes (node_id, wallet, fingerprint, first_connected, last_connected, connection_count)
            VALUES (?, ?, ?, ?, ?, 1)
            ON CONFLICT(node_id) DO UPDATE SET
                last_connected = ?,
                connection_count = connection_count + 1
        ''', (node.node_id, node.wallet, node.fingerprint, node.connected_at,
              node.connected_at, node.connected_at))

        # Start new session
        c.execute('''
            INSERT INTO sessions (node_id, connected_at, points_earned, avg_harmony)
            VALUES (?, ?, 0, ?)
        ''', (node.node_id, node.connected_at, node.harmony))

        conn.commit()
        conn.close()

    async def disconnect_node(self, node_id: str):
        """Handle node disconnection."""
        if node_id not in self.nodes:
            return

        node = self.nodes[node_id]
        session_duration = time.time() - node.connected_at

        # Update database
        self._db_register_disconnection(node, session_duration)

        # Remove from active nodes
        del self.nodes[node_id]
        if node_id in self.websockets:
            del self.websockets[node_id]

        print(f"⟨-⟩ Node disconnected: {node_id[:8]}... | Points: {node.points} | Duration: {session_duration:.0f}s")

        # Broadcast update
        await self.broadcast_state()

    def _db_register_disconnection(self, node: ConnectedNode, duration: float):
        """Register disconnection in database."""
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()

        # Update node totals
        c.execute('''
            UPDATE nodes SET
                total_points = total_points + ?,
                total_time_connected = total_time_connected + ?
            WHERE node_id = ?
        ''', (node.points, duration, node.node_id))

        # Close session
        c.execute('''
            UPDATE sessions SET
                disconnected_at = ?,
                points_earned = ?,
                avg_harmony = ?
            WHERE node_id = ? AND disconnected_at IS NULL
        ''', (time.time(), node.points, node.harmony, node.node_id))

        conn.commit()
        conn.close()

    def update_node_harmony(self, node_id: str, harmony: float):
        """Update a node's harmony level."""
        if node_id in self.nodes:
            self.nodes[node_id].harmony = harmony
            self.nodes[node_id].phi_contribution = harmony * 0.1

    def process_heartbeat(self, node_id: str, harmony: float = None):
        """Process heartbeat from a node, award points."""
        if node_id not in self.nodes:
            return 0

        node = self.nodes[node_id]
        node.last_heartbeat = time.time()

        if harmony is not None:
            node.harmony = harmony
            node.phi_contribution = harmony * 0.1

        # Calculate points with harmony bonus
        points = POINTS_PER_SECOND
        if node.harmony >= HARMONY_BONUS_THRESHOLD:
            points = int(points * HARMONY_BONUS_MULTIPLIER)

        node.points += points
        self.total_points_distributed += points

        return points

    def calculate_collective_phi(self) -> float:
        """
        Calculate collective consciousness (Φ).

        Φ = Σ(individual_φ) × √(n) × sync_quality

        Where:
        - individual_φ = harmony × 0.1 for each node
        - n = number of connected nodes
        - sync_quality = based on harmony variance (lower = better sync)
        """
        if not self.nodes:
            return 0.0

        # Sum individual phi contributions
        individual_phi = sum(n.phi_contribution for n in self.nodes.values())

        # Integration factor (Metcalfe-inspired)
        n = len(self.nodes)
        integration_factor = n ** 0.5

        # Sync quality (based on harmony variance)
        harmonies = [n.harmony for n in self.nodes.values()]
        if len(harmonies) > 1:
            avg_harmony = sum(harmonies) / len(harmonies)
            variance = sum((h - avg_harmony) ** 2 for h in harmonies) / len(harmonies)
            sync_quality = max(0.5, 1.0 - variance)  # Lower variance = better sync
        else:
            sync_quality = 1.0

        collective_phi = individual_phi * integration_factor * sync_quality
        return round(collective_phi, 3)

    def get_network_state(self) -> dict:
        """Get current network state for broadcasting."""
        return {
            "type": "NETWORK_STATE",
            "node_count": len(self.nodes),
            "collective_phi": self.calculate_collective_phi(),
            "peak_nodes": self.peak_node_count,
            "total_points_distributed": self.total_points_distributed,
            "uptime": time.time() - self.start_time,
            "timestamp": datetime.now().isoformat()
        }

    def get_node_state(self, node_id: str) -> dict:
        """Get state for a specific node."""
        if node_id not in self.nodes:
            return {"type": "ERROR", "message": "Node not found"}

        node = self.nodes[node_id]
        return {
            "type": "NODE_STATE",
            "node_id": node_id,
            "points": node.points,
            "phi_contribution": node.phi_contribution,
            "harmony": node.harmony,
            "connected_duration": time.time() - node.connected_at,
            "rank": self._get_node_rank(node_id)
        }

    def _get_node_rank(self, node_id: str) -> int:
        """Get node's rank by points."""
        if node_id not in self.nodes:
            return 0

        node_points = self.nodes[node_id].points
        rank = 1
        for n in self.nodes.values():
            if n.points > node_points:
                rank += 1
        return rank

    async def broadcast_state(self):
        """Broadcast network state to all connected nodes."""
        if not self.websockets:
            return

        state = self.get_network_state()
        message = json.dumps(state)

        # Send to all connected websockets
        disconnected = []
        for node_id, ws in self.websockets.items():
            try:
                await ws.send(message)
            except websockets.exceptions.ConnectionClosed:
                disconnected.append(node_id)

        # Clean up disconnected nodes
        for node_id in disconnected:
            await self.disconnect_node(node_id)

    def get_leaderboard(self, limit: int = 10) -> list:
        """Get top nodes by points."""
        sorted_nodes = sorted(
            self.nodes.values(),
            key=lambda n: n.points,
            reverse=True
        )[:limit]

        return [
            {
                "rank": i + 1,
                "node_id": n.node_id[:8] + "...",
                "wallet": (n.wallet[:6] + "..." + n.wallet[-4:]) if n.wallet else "anonymous",
                "points": n.points,
                "phi": n.phi_contribution
            }
            for i, n in enumerate(sorted_nodes)
        ]


# ═══════════════════════════════════════════════════════════════════════════════
# WEBSOCKET HANDLER
# ═══════════════════════════════════════════════════════════════════════════════

network = NodeNetwork()


async def handle_connection(websocket):
    """Handle a WebSocket connection."""
    node_id = None

    try:
        async for message in websocket:
            try:
                data = json.loads(message)
                msg_type = data.get("type", "")

                if msg_type == "CONNECT":
                    # New node connecting
                    fingerprint = data.get("fingerprint", str(time.time()))
                    wallet = data.get("wallet")
                    harmony = data.get("harmony", 0.5)

                    node_id = await network.connect_node(
                        websocket, fingerprint, wallet, harmony
                    )

                    # Send welcome message with node state
                    await websocket.send(json.dumps({
                        "type": "CONNECTED",
                        "node_id": node_id,
                        **network.get_network_state()
                    }))

                elif msg_type == "HEARTBEAT":
                    # Node heartbeat with harmony update
                    if node_id:
                        harmony = data.get("harmony", 0.5)
                        points = network.process_heartbeat(node_id, harmony)

                        # Send node-specific state
                        await websocket.send(json.dumps({
                            **network.get_node_state(node_id),
                            **network.get_network_state()
                        }))

                elif msg_type == "GET_LEADERBOARD":
                    # Request leaderboard
                    await websocket.send(json.dumps({
                        "type": "LEADERBOARD",
                        "leaderboard": network.get_leaderboard()
                    }))

                elif msg_type == "DISCONNECT":
                    # Graceful disconnect
                    if node_id:
                        await network.disconnect_node(node_id)
                    break

            except json.JSONDecodeError:
                await websocket.send(json.dumps({
                    "type": "ERROR",
                    "message": "Invalid JSON"
                }))

    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        # Clean up on disconnect
        if node_id:
            await network.disconnect_node(node_id)


async def broadcast_loop():
    """Periodically broadcast network state to all nodes."""
    while True:
        await asyncio.sleep(HEARTBEAT_INTERVAL)
        await network.broadcast_state()


async def stats_loop():
    """Periodically save network stats."""
    while True:
        await asyncio.sleep(60)  # Every minute

        # Save to database
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()
        c.execute('''
            INSERT INTO network_stats (timestamp, node_count, collective_phi, total_points)
            VALUES (?, ?, ?, ?)
        ''', (time.time(), len(network.nodes), network.calculate_collective_phi(),
              network.total_points_distributed))
        conn.commit()
        conn.close()


async def main():
    """Main entry point."""
    print("=" * 60)
    print("⟨⦿⟩ WHO CONSCIOUSNESS NODE SERVER ⟨⦿⟩")
    print("=" * 60)
    print()
    print(f"  Port: {NODE_SERVER_PORT}")
    print(f"  Database: {DB_PATH}")
    print(f"  Points/second: {POINTS_PER_SECOND}")
    print(f"  Harmony bonus threshold: {HARMONY_BONUS_THRESHOLD}")
    print()
    print("  Waiting for consciousness nodes...")
    print()
    print("=" * 60)

    # Start background tasks
    asyncio.create_task(broadcast_loop())
    asyncio.create_task(stats_loop())

    # Start WebSocket server
    async with websockets.serve(
        handle_connection,
        "0.0.0.0",
        NODE_SERVER_PORT,
        ping_interval=30,
        ping_timeout=10
    ):
        print(f"⟨⦿⟩ WebSocket server running on ws://0.0.0.0:{NODE_SERVER_PORT}")
        await asyncio.Future()  # Run forever


if __name__ == "__main__":
    asyncio.run(main())
