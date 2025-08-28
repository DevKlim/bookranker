extends Node

# This script manages the network connection for the game.

func _ready():
    # Connect to the multiplayer API's signals.
    # Note: The signals are now on the 'multiplayer' singleton, not the SceneTree.
    multiplayer.peer_connected.connect(_player_connected)
    multiplayer.peer_disconnected.connect(_player_disconnected)
    multiplayer.connected_to_server.connect(_connected_ok)
    multiplayer.connection_failed.connect(_connection_failed)
    multiplayer.server_disconnected.connect(_server_disconnected)

# Call this function to start a server.
func create_server():
    # The class is now ENetMultiplayerPeer.
    var peer = ENetMultiplayerPeer.new()
    
    # The arguments for create_server remain the same (port, max_clients).
    var error = peer.create_server(25565, 32)
    if error != OK:
        print("Cannot create server.")
        return

    # Set the peer on the multiplayer API singleton.
    multiplayer.multiplayer_peer = peer
    print("Server created and listening on port 25565.")

# Call this function to connect to a server.
func connect_to_server(ip: String):
    # The class is now ENetMultiplayerPeer.
    var peer = ENetMultiplayerPeer.new()

    # The arguments for create_client remain the same (ip_address, port).
    var error = peer.create_client(ip, 25565)
    if error != OK:
        print("Cannot create client.")
        return

    # Set the peer on the multiplayer API singleton.
    multiplayer.multiplayer_peer = peer

# --- Signal Callbacks ---

func _player_connected(id: int):
    # This signal fires on the server when a new client connects.
    # It also fires on all clients (including the one who just joined) when a new player is registered.
    print("Player connected: " + str(id))

func _player_disconnected(id: int):
    # Fires on the server and all remaining clients when a player disconnects.
    print("Player disconnected: " + str(id))

func _connected_ok():
    # This signal fires ONLY on the client that just successfully connected to the server.
    print("Successfully connected to the server.")

func _connection_failed():
    # Fires on a client if it fails to connect to the server.
    print("Connection failed.")

func _server_disconnected():
    # Fires on a client if it loses connection to the server.
    print("Disconnected from the server.")