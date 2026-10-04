//! RP2040 single-buffer control fields, datasheet section 4.1.2.7.1.
pub const available: u32 = 1 << 10;
pub const stall: u32 = 1 << 11;
pub const pid: u32 = 1 << 13;
pub const full: u32 = 1 << 15;

/// Call only after EP_ABORT_DONE grants ownership (or a bus reset).
/// HAL write/listen XOR the PID bit, so zero starts both directions DATA1.
pub fn prepareSetup(raw: u32) u32 {
    return raw & ~(available | full | stall | pid);
}

/// EP_ABORT_DONE is write-one-to-clear, not a read/modify/write register.
pub fn abortDoneAck(mask: u32) u32 {
    return mask;
}
