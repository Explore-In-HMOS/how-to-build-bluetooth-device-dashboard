// entry/src/main/ets/managers/BluetoothManager.ets

import {
  a2dp, hfp, hid, pan, constant, connection, baseProfile, access
} from '@kit.ConnectivityKit';
import { abilityAccessCtrl, Permissions, Context } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * Represents a discovered or paired Bluetooth device
 */
interface BluetoothDeviceItem {
  /** Display name of the device */
  deviceName: string;

  /** MAC address of the device */
  deviceAddress: string;

  /** Whether the device is already paired with the system */
  isPaired: boolean;
}

/**
 * Singleton manager for all Bluetooth operations including device discovery,
 * profile management (A2DP, HFP, HID, PAN), and connection control.
 *
 * @remarks
* This class implements the OpenHarmony Connectivity Kit Bluetooth APIs.
 * It uses the `connection` module for discovery and the profile-specific
 * modules for A2DP, HFP, HID, and PAN management.
 */
export class BluetoothManager {
  private static instance: BluetoothManager;
  // Profile instances
  private a2dpProfile: a2dp.A2dpSourceProfile | null = null;
  private hfpProfile: hfp.HandsFreeAudioGatewayProfile | null = null;
  private hidProfile: hid.HidHostProfile | null = null;
  private panProfile: pan.PanProfile | null = null;
  // Connection states for each profile
  public a2dpState: constant.ProfileConnectionState = constant.ProfileConnectionState.STATE_DISCONNECTED;
  public hfpState: constant.ProfileConnectionState = constant.ProfileConnectionState.STATE_DISCONNECTED;
  public hidState: constant.ProfileConnectionState = constant.ProfileConnectionState.STATE_DISCONNECTED;
  public panState: constant.ProfileConnectionState = constant.ProfileConnectionState.STATE_DISCONNECTED;
  // Device lists
  public allDevicesList: Array<BluetoothDeviceItem> = [];
  public pairedDevicesList: Array<BluetoothDeviceItem> = [];
  public discoveredDevicesList: Array<BluetoothDeviceItem> = [];
  // Current selected device
  public selectedDeviceAddress: string = '';
  public selectedDeviceName: string = '';
  public bondState: string = '';
  // UI state flags
  public isConnecting: boolean = false;
  public isScanning: boolean = false;
  public lastError: string = '';
  // UI update callbacks
  public onStateChange: (() => void) | null = null;
  public onDeviceListUpdate: (() => void) | null = null;

  private constructor() {
  }

  /**
   * Gets the singleton instance of BluetoothManager
   * @returns The singleton instance
   */
  static getInstance(): BluetoothManager {
    if (!BluetoothManager.instance) {
      BluetoothManager.instance = new BluetoothManager();
    }
    return BluetoothManager.instance;
  }

  /**
   * Callback for discoveryResult event (API 18+)
   * Provides rich device information including name, address, and RSSI
   *
   * @param data - Array of discovered devices with full information
   */
  private onDiscoveryResult = (data: Array<connection.DiscoveryResult>): void => {
    console.info(`[DiscoveryResult] Found ${data.length} devices`);
    for (const device of data) {
      this.addDiscoveredDeviceFromResult(device);
    }
    this.onDeviceListUpdate?.();
  };
  /**
   * Fallback callback for bluetoothDeviceFind event (API 17 or earlier)
   * Provides only device addresses
   *
   * @param data - Array of discovered device addresses
   */
  private onBluetoothDeviceFind = (data: Array<string>): void => {
    console.info(`[DeviceFind] Found ${data.length} devices`);
    for (const deviceAddress of data) {
      this.addDiscoveredDeviceFromAddress(deviceAddress);
    }
    this.onDeviceListUpdate?.();
  };

  /**
   * Adds a discovered device using rich information from discoveryResult event
   *
   * @param device - Discovery result containing device details
   */
  private addDiscoveredDeviceFromResult(device: connection.DiscoveryResult): void {
    const exists = this.allDevicesList.some(d => d.deviceAddress === device.deviceId);
    if (exists) {
      return;
    }

    const isPaired = this.isDevicePaired(device.deviceId);
    const newDevice: BluetoothDeviceItem = {
      deviceName: device.deviceName || 'Unknown Device',
      deviceAddress: device.deviceId,
      isPaired: isPaired
    };

    this.addDeviceToList(newDevice);
  }

  /**
   * Adds a discovered device using address from bluetoothDeviceFind event
   * Resolves the device name using getRemoteDeviceName
   *
   * @param deviceAddress - MAC address of the discovered device
   */
  private addDiscoveredDeviceFromAddress(deviceAddress: string): void {
    const exists = this.allDevicesList.some(device => device.deviceAddress === deviceAddress);
    if (exists) {
      return;
    }

    let deviceName = 'Unknown Device';
    try {
      deviceName = connection.getRemoteDeviceName(deviceAddress);
    } catch (err) {
      console.error(`Failed to get name for ${deviceAddress}`);
    }

    const isPaired = this.isDevicePaired(deviceAddress);
    const newDevice: BluetoothDeviceItem = {
      deviceName: deviceName,
      deviceAddress: deviceAddress,
      isPaired: isPaired
    };

    this.addDeviceToList(newDevice);
  }

  /**
   * Adds a device to the appropriate lists (all, paired, or discovered)
   *
   * @param device - Device to add to lists
   */
  private addDeviceToList(device: BluetoothDeviceItem): void {
    this.allDevicesList.push(device);

    if (device.isPaired) {
      this.pairedDevicesList.push(device);
    } else {
      this.discoveredDevicesList.push(device);
    }
  }

  /**
   * Checks if a device is paired with the system
   *
   * @param deviceAddress - MAC address of the device to check
   * @returns True if the device is paired, false otherwise
   */
  private isDevicePaired(deviceAddress: string): boolean {
    try {
      const pairState = connection.getPairState(deviceAddress);
      return pairState === 2; // BondState.BOND_STATE_BONDED = 2
    } catch (err) {
      try {
        const pairedAddresses = connection.getPairedDevices();
        return pairedAddresses.includes(deviceAddress);
      } catch (e) {
        return false;
      }
    }
  }

  /**
   * Starts scanning for nearby Bluetooth devices
   *
   * @returns Promise resolving to true if scan started successfully, false otherwise
   */
  async startDeviceDiscovery(): Promise<boolean> {
    if (!this.isBluetoothEnabled()) {
      this.lastError = 'Bluetooth is not enabled';
      return false;
    }

    if (this.isScanning) {
      return true;
    }

    try {
      this.clearDiscoveredDevices();

      try {
        connection.on('discoveryResult', this.onDiscoveryResult);
      } catch (err) {
        connection.on('bluetoothDeviceFind', this.onBluetoothDeviceFind);
      }

      const isDiscovering = connection.isBluetoothDiscovering();
      if (!isDiscovering) {
        connection.startBluetoothDiscovery();
      }

      this.isScanning = true;
      this.lastError = '';
      return true;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`Start discovery failed: ${error.code} - ${error.message}`);
      this.lastError = `Discovery failed: ${error.message}`;
      return false;
    }
  }

  /**
   * Stops scanning for Bluetooth devices
   *
   * @returns Promise that resolves when scanning is stopped
   */
  async stopDeviceDiscovery(): Promise<void> {
    if (!this.isScanning) {
      return;
    }

    try {
      const isDiscovering = connection.isBluetoothDiscovering();
      if (isDiscovering) {
        connection.stopBluetoothDiscovery();
      }

      try {
        connection.off('discoveryResult', this.onDiscoveryResult);
      } catch (err) {
      }
      try {
        connection.off('bluetoothDeviceFind', this.onBluetoothDeviceFind);
      } catch (err) {
      }

      this.isScanning = false;
    } catch (err) {
      console.error('Failed to stop discovery', err);
    }
  }

  /**
   * Clears the list of discovered (unpaired) devices
   */
  clearDiscoveredDevices(): void {
    this.discoveredDevicesList = [];
    this.allDevicesList = [...this.pairedDevicesList];
    this.onDeviceListUpdate?.();
  }

  /**
   * Refreshes the device list by reloading paired devices and starting a new scan
   */
  refreshAllDevices(): void {
    this.loadPairedDevices();
    this.startDeviceDiscovery();
  }

  /**
   * Loads the list of already paired devices from the system
   */
  loadPairedDevices(): void {
    try {
      const deviceAddresses: Array<string> = connection.getPairedDevices();
      console.info(`Found ${deviceAddresses.length} paired devices`);

      const devices: Array<BluetoothDeviceItem> = [];
      for (const addr of deviceAddresses) {
        let deviceName = addr;
        try {
          deviceName = connection.getRemoteDeviceName(addr);
        } catch (err) {
          console.error(`Failed to get name for ${addr}`);
        }

        devices.push({
          deviceName: deviceName,
          deviceAddress: addr,
          isPaired: true
        });
      }

      this.pairedDevicesList = devices;
      this.allDevicesList = [...devices, ...this.discoveredDevicesList];
      this.onDeviceListUpdate?.();

      if (devices.length === 0) {
        this.lastError = 'No paired devices found. Start scanning to find new devices.';
      } else {
        this.lastError = '';
      }
    } catch (err) {
      const error = err as BusinessError;
      console.error('Failed to get paired devices', error);
      this.lastError = `Failed to get paired devices: ${error.code} - ${error.message}`;
      this.pairedDevicesList = [];
      this.onDeviceListUpdate?.();
    }
  }

  /**
   * Checks if Bluetooth is currently enabled on the device
   *
   * @returns True if Bluetooth is enabled, false otherwise
   */
  private isBluetoothEnabled(): boolean {
    try {
      const state = access.getState();
      return state === access.BluetoothState.STATE_ON;
    } catch (err) {
      return false;
    }
  }

  /**
   * Requests the required Bluetooth permissions from the user
   *
   * @param context - Current application context
   * @returns Promise resolving to true if permissions granted, false otherwise
   */
  async requestPermissions(context: Context): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const permissions: Array<Permissions> = [
        'ohos.permission.ACCESS_BLUETOOTH'
      ];

      const result = await atManager.requestPermissionsFromUser(context, permissions);

      let allGranted: boolean = true;
      for (let i: number = 0; i < result.authResults.length; i++) {
        if (result.authResults[i] !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          allGranted = false;
          console.error(`Permission ${permissions[i]} denied`);
        }
      }

      if (!allGranted) {
        this.lastError = 'Bluetooth permission not granted';
        return false;
      }

      return true;
    } catch (err) {
      console.error('Permission request failed', err);
      this.lastError = 'Permission request failed';
      return false;
    }
  }

  /**
   * Attempts to enable Bluetooth on the device
   *
   * @returns Promise resolving to true if Bluetooth was enabled successfully, false otherwise
   */
  async enableBluetooth(): Promise<boolean> {
    try {
      if (this.isBluetoothEnabled()) {
        return true;
      }

      access.enableBluetooth();
      await this.sleep(500);

      if (this.isBluetoothEnabled()) {
        return true;
      } else {
        this.lastError = 'Bluetooth could not be enabled';
        return false;
      }
    } catch (err) {
      const error = err as BusinessError;
      console.error(`Bluetooth enable failed: ${error.code} - ${error.message}`);
      this.lastError = `Bluetooth enable failed: ${error.message}`;
      return false;
    }
  }

  /**
   * Sets the local device's Bluetooth scan mode to discoverable
   * Note: Typically not required for non-system applications
   */
  setDiscoverableScanMode(): void {
    try {
      const currentMode = connection.getBluetoothScanMode();
      if (currentMode !== connection.ScanMode.SCAN_MODE_CONNECTABLE_GENERAL_DISCOVERABLE) {
        connection.setBluetoothScanMode(connection.ScanMode.SCAN_MODE_CONNECTABLE_GENERAL_DISCOVERABLE, 0);
      }
    } catch (err) {
      console.error('Failed to set scan mode', err);
    }
  }

  private onA2dpConnectStateChange = (data: baseProfile.StateChangeParam): void => {
    if (data.deviceId === this.selectedDeviceAddress) {
      this.a2dpState = data.state;
      this.onStateChange?.();
    }
  };
  private onHfpConnectStateChange = (data: baseProfile.StateChangeParam): void => {
    if (data.deviceId === this.selectedDeviceAddress) {
      this.hfpState = data.state;
      this.onStateChange?.();
    }
  };
  private onHidConnectStateChange = (data: baseProfile.StateChangeParam): void => {
    if (data.deviceId === this.selectedDeviceAddress) {
      this.hidState = data.state;
      this.onStateChange?.();
    }
  };
  private onPanConnectStateChange = (data: baseProfile.StateChangeParam): void => {
    if (data.deviceId === this.selectedDeviceAddress) {
      this.panState = data.state;
      this.onStateChange?.();
    }
  };

  /**
   * Initializes all Bluetooth profile instances (A2DP, HFP, HID, PAN)
   * and sets up event listeners for state changes
   *
   * @returns Promise resolving to true if initialization succeeded, false otherwise
   */
  async initProfiles(): Promise<boolean> {
    try {
      this.a2dpProfile = a2dp.createA2dpSrcProfile();
      this.hfpProfile = hfp.createHfpAgProfile();
      this.hidProfile = hid.createHidHostProfile();
      this.panProfile = pan.createPanProfile();

      this.setupEventListeners();
      return true;
    } catch (err) {
      const error = err as BusinessError;
      this.lastError = `Profile init failed: ${error.code} - ${error.message}`;
      return false;
    }
  }

  /**
   * Sets up event listeners for connection state changes on all profiles
   */
  private setupEventListeners(): void {
    if (this.a2dpProfile) {
      this.a2dpProfile.on('connectionStateChange', this.onA2dpConnectStateChange);
    }
    if (this.hfpProfile) {
      this.hfpProfile.on('connectionStateChange', this.onHfpConnectStateChange);
    }
    if (this.hidProfile) {
      this.hidProfile.on('connectionStateChange', this.onHidConnectStateChange);
    }
    if (this.panProfile) {
      this.panProfile.on('connectionStateChange', this.onPanConnectStateChange);
    }
  }

  /**
   * Removes all event listeners from profiles
   */
  private removeEventListeners(): void {
    if (this.a2dpProfile) {
      this.a2dpProfile.off('connectionStateChange', this.onA2dpConnectStateChange);
    }
    if (this.hfpProfile) {
      this.hfpProfile.off('connectionStateChange', this.onHfpConnectStateChange);
    }
    if (this.hidProfile) {
      this.hidProfile.off('connectionStateChange', this.onHidConnectStateChange);
    }
    if (this.panProfile) {
      this.panProfile.off('connectionStateChange', this.onPanConnectStateChange);
    }
  }

  /**
   * Selects a device for connection
   *
   * @param deviceAddress - MAC address of the device to select
   * @param deviceName - Display name of the device
   */
  selectDevice(deviceAddress: string, deviceName: string): void {
    this.selectedDeviceAddress = deviceAddress;
    this.selectedDeviceName = deviceName;
    this.bondState = this.isDevicePaired(deviceAddress) ? 'Paired' : 'Not Paired';
    console.info(`Selected device: ${this.selectedDeviceName} (${this.selectedDeviceAddress})`);
    this.onStateChange?.();
  }

  /**
   * Refreshes the connection state for all profiles of the selected device
   *
   * @returns Promise that resolves when states are refreshed
   */
  async refreshAllConnectionStates(): Promise<void> {
    if (!this.selectedDeviceAddress) {
      return;
    }

    try {
      if (this.a2dpProfile) {
        this.a2dpState = await this.a2dpProfile.getConnectionState(this.selectedDeviceAddress);
      }
      if (this.hfpProfile) {
        this.hfpState = await this.hfpProfile.getConnectionState(this.selectedDeviceAddress);
      }
      if (this.hidProfile) {
        this.hidState = await this.hidProfile.getConnectionState(this.selectedDeviceAddress);
      }
      if (this.panProfile) {
        this.panState = await this.panProfile.getConnectionState(this.selectedDeviceAddress);
      }
      this.onStateChange?.();
    } catch (err) {
      console.error('Failed to refresh states', err);
    }
  }

  /**
   * Connects to the selected device using all supported profiles (A2DP, HFP, HID)
   *
   * @returns Promise resolving to true if connection succeeded, false otherwise
   */
  async connectToDevice(): Promise<boolean> {
    if (!this.isBluetoothEnabled()) {
      this.lastError = 'Bluetooth is not enabled';
      return false;
    }

    if (!this.selectedDeviceAddress) {
      this.lastError = 'No device selected';
      return false;
    }

    if (!this.isDevicePaired(this.selectedDeviceAddress)) {
      this.lastError = 'Device not paired. Please pair first in system settings.';
      return false;
    }

    if (this.isConnecting) {
      this.lastError = 'Connection already in progress';
      return false;
    }

    this.isConnecting = true;

    try {
      console.info(`Connecting to device: ${this.selectedDeviceAddress}`);
      await connection.connectAllowedProfiles(this.selectedDeviceAddress);
      await this.sleep(1000);
      await this.refreshAllConnectionStates();
      this.lastError = '';
      return true;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`Connection error: ${error.code} - ${error.message}`);
      this.lastError = `Connection failed: ${error.message}`;
      return false;
    } finally {
      this.isConnecting = false;
    }
  }

  /**
   * Sleep utility for async delays
   *
   * @param ms - Milliseconds to sleep
   * @returns Promise that resolves after the specified time
   */
  private async sleep(ms: number): Promise<void> {
    return new Promise((resolve: () => void) => setTimeout(resolve, ms));
  }

  /**
   * Cleans up resources by stopping discovery and removing event listeners
   */
  cleanup(): void {
    this.stopDeviceDiscovery();
    this.removeEventListeners();
  }

  /**
   * Converts a connection state constant to a human-readable string
   *
   * @param state - ProfileConnectionState constant value
   * @returns Human-readable status text
   */
  getStateText(state: constant.ProfileConnectionState): string {
    if (state === constant.ProfileConnectionState.STATE_DISCONNECTED) {
      return 'Disconnected';
    }
    if (state === constant.ProfileConnectionState.STATE_CONNECTING) {
      return 'Connecting...';
    }
    if (state === constant.ProfileConnectionState.STATE_CONNECTED) {
      return 'Connected ✓';
    }
    if (state === constant.ProfileConnectionState.STATE_DISCONNECTING) {
      return 'Disconnecting...';
    }
    return 'Unknown';
  }

  /**
   * Returns a color code for a given connection state
   *
   * @param state - ProfileConnectionState constant value
   * @returns Hex color code for the state
   */
  getStateColor(state: constant.ProfileConnectionState): string {
    if (state === constant.ProfileConnectionState.STATE_CONNECTED) {
      return '#10b981';
    }
    if (state === constant.ProfileConnectionState.STATE_CONNECTING) {
      return '#f59e0b';
    }
    if (state === constant.ProfileConnectionState.STATE_DISCONNECTING) {
      return '#f59e0b';
    }
    return '#6b7280';
  }
}