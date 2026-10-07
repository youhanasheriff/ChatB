"""Exercise the real discovery binary against an isolated, mocked system bus.

Requires Debian/Ubuntu's python3-dbusmock; never connects to the host BlueZ bus.
"""
import os
from pathlib import Path
import signal
import subprocess
import time
import unittest

import dbus
import dbusmock

MAINNET = "f47b5e2d-4a9e-4c5a-9b3f-8e1d2c3a4b5c"
TESTNET = "f47b5e2d-4a9e-4c5a-9b3f-8e1d2c3a4b5a"
BINARY = str(Path(os.environ.get("BITCHAT_LINUX_BINARY", "target/debug/bitchat-desktop")).resolve())


class BlueZDiscoveryTests(dbusmock.DBusTestCase):
    @classmethod
    def setUpClass(cls):
        cls.start_system_bus()
        cls.bus = cls.get_dbus(True)

    def setUp(self):
        self.server, root = self.spawn_server_template("bluez5", {}, stdout=subprocess.DEVNULL)
        self.addCleanup(self.server.wait)
        self.addCleanup(self.server.terminate)
        self.mock = dbus.Interface(root, "org.bluez.Mock")

    def adapter(self, name="hci0", powered=True):
        path = self.mock.AddAdapter(name, "Discovery test adapter")
        adapter = self.bus.get_object("org.bluez", path)
        adapter.UpdateProperties("org.bluez.Adapter1", {"Powered": dbus.Boolean(powered)},
                                 dbus_interface=dbusmock.MOCK_IFACE)
        return adapter

    def device(self, address, name, uuid):
        path = self.mock.AddDevice("hci0", address, name)
        device = self.bus.get_object("org.bluez", path)
        device.UpdateProperties("org.bluez.Device1", {"UUIDs": dbus.Array([uuid], signature="s")},
                                dbus_interface=dbusmock.MOCK_IFACE)
        return device

    def scan(self, *args):
        return subprocess.run([BINARY, "--scan", "--seconds", "1", *args],
                              capture_output=True, text=True, timeout=8)

    def start_scan(self, adapter):
        process = subprocess.Popen([BINARY, "--scan", "--seconds", "10"],
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.addCleanup(lambda: process.poll() is None and process.kill())
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if adapter.Get("org.bluez.Adapter1", "Discovering", dbus_interface=dbus.PROPERTIES_IFACE):
                return process
            if process.poll() is not None:
                self.fail(f"Scan exited before discovery: {process.communicate()}")
            time.sleep(0.03)
        self.fail("Scan did not start discovery")

    def test_no_adapter_fails_instead_of_reporting_empty_success(self):
        result = self.scan()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("No Bluetooth adapter", result.stderr)

    def test_powered_off_adapter_is_not_silently_enabled(self):
        adapter = self.adapter(powered=False)
        result = self.scan()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("turned off", result.stderr)
        self.assertFalse(adapter.Get("org.bluez.Adapter1", "Powered", dbus_interface=dbus.PROPERTIES_IFACE))

    def test_locally_filters_merged_bluez_results_and_selects_network(self):
        self.adapter()
        self.device("11:22:33:44:55:01", "Mainnet phone", MAINNET)
        self.device("11:22:33:44:55:02", "Testnet phone", TESTNET)
        self.device("11:22:33:44:55:03", "Unrelated device", "0000180f-0000-1000-8000-00805f9b34fb")
        for arguments, included, excluded in [((), "Mainnet phone", "Testnet phone"),
                                              (("--testnet",), "Testnet phone", "Mainnet phone")]:
            result = self.scan(*arguments)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("1 matching device(s)", result.stdout)
            self.assertIn(included, result.stdout)
            self.assertNotIn(excluded, result.stdout)
            self.assertNotIn("Unrelated device", result.stdout)

    def test_ctrl_c_releases_discovery(self):
        adapter = self.adapter()
        process = self.start_scan(adapter)
        process.send_signal(signal.SIGINT)
        out, err = process.communicate(timeout=5)
        self.assertEqual(process.returncode, 0, err)
        self.assertIn("matching device(s)", out)
        self.assertFalse(adapter.Get("org.bluez.Adapter1", "Discovering", dbus_interface=dbus.PROPERTIES_IFACE))

    def test_radio_power_loss_is_reported(self):
        adapter = self.adapter()
        process = self.start_scan(adapter)
        adapter.UpdateProperties("org.bluez.Adapter1", {"Powered": dbus.Boolean(False)},
                                 dbus_interface=dbusmock.MOCK_IFACE)
        _, err = process.communicate(timeout=6)
        self.assertEqual(process.returncode, 1, err)
        self.assertIn("turned off", err)

    def test_permission_denied_is_actionable(self):
        adapter = self.adapter()
        adapter.AddMethod("org.bluez.Adapter1", "StartDiscovery", "", "",
                          "raise dbus.exceptions.DBusException('Denied', name='org.bluez.Error.NotAuthorized')",
                          dbus_interface=dbusmock.MOCK_IFACE)
        result = self.scan()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("access was denied", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
