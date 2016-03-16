// RO: Device ID
    localparam PCI_Header__ID__DID__ADDR = 'h60;
    localparam PCI_Header__ID__DID__MASK = 'hffff0000;
    localparam PCI_Header__ID__DID__DFLT = 'h10000;
// RO: Vendor ID
    localparam PCI_Header__ID__VID__ADDR = 'h60;
    localparam PCI_Header__ID__VID__MASK = 'hffff;
    localparam PCI_Header__ID__VID__DFLT = 'hfffe;
// RW: HBA Interrupt Disable
    localparam PCI_Header__CMD__ID__ADDR = 'h61;
    localparam PCI_Header__CMD__ID__MASK = 'h400;
    localparam PCI_Header__CMD__ID__DFLT = 'h0;
// RO: Fast Back-to-Back Enable
    localparam PCI_Header__CMD__FBE__ADDR = 'h61;
    localparam PCI_Header__CMD__FBE__MASK = 'h200;
    localparam PCI_Header__CMD__FBE__DFLT = 'h0;
// RO: SERR Enable
    localparam PCI_Header__CMD__SEE__ADDR = 'h61;
    localparam PCI_Header__CMD__SEE__MASK = 'h100;
    localparam PCI_Header__CMD__SEE__DFLT = 'h0;
// RO: Reserved
    localparam PCI_Header__CMD__WCC__ADDR = 'h61;
    localparam PCI_Header__CMD__WCC__MASK = 'h80;
    localparam PCI_Header__CMD__WCC__DFLT = 'h0;
// RO: Parity Error Response Enable
    localparam PCI_Header__CMD__PEE__ADDR = 'h61;
    localparam PCI_Header__CMD__PEE__MASK = 'h40;
    localparam PCI_Header__CMD__PEE__DFLT = 'h0;
// RO: Reserved
    localparam PCI_Header__CMD__VGA__ADDR = 'h61;
    localparam PCI_Header__CMD__VGA__MASK = 'h20;
    localparam PCI_Header__CMD__VGA__DFLT = 'h0;
// RO: Reserved
    localparam PCI_Header__CMD__MWIE__ADDR = 'h61;
    localparam PCI_Header__CMD__MWIE__MASK = 'h10;
    localparam PCI_Header__CMD__MWIE__DFLT = 'h0;
// RO: Reserved
    localparam PCI_Header__CMD__SCE__ADDR = 'h61;
    localparam PCI_Header__CMD__SCE__MASK = 'h8;
    localparam PCI_Header__CMD__SCE__DFLT = 'h0;
// RW: Bus Master Enable (0 - stops any DMA)
    localparam PCI_Header__CMD__BME__ADDR = 'h61;
    localparam PCI_Header__CMD__BME__MASK = 'h4;
    localparam PCI_Header__CMD__BME__DFLT = 'h0;
// RW: Memory Space enable (here - always?)
    localparam PCI_Header__CMD__MSE__ADDR = 'h61;
    localparam PCI_Header__CMD__MSE__MASK = 'h2;
    localparam PCI_Header__CMD__MSE__DFLT = 'h0;
// RO: Enable IO space access (only for legacy IDE)
    localparam PCI_Header__CMD__IOSE__ADDR = 'h61;
    localparam PCI_Header__CMD__IOSE__MASK = 'h1;
    localparam PCI_Header__CMD__IOSE__DFLT = 'h0;
// RWC: Detected Parity Error
    localparam PCI_Header__STS__DPE__ADDR = 'h61;
    localparam PCI_Header__STS__DPE__MASK = 'h80000000;
    localparam PCI_Header__STS__DPE__DFLT = 'h0;
// RWC: Signaled System Error (HBA SERR)
    localparam PCI_Header__STS__SSE__ADDR = 'h61;
    localparam PCI_Header__STS__SSE__MASK = 'h40000000;
    localparam PCI_Header__STS__SSE__DFLT = 'h0;
// RWC: Received Master Abort
    localparam PCI_Header__STS__RMA__ADDR = 'h61;
    localparam PCI_Header__STS__RMA__MASK = 'h20000000;
    localparam PCI_Header__STS__RMA__DFLT = 'h0;
// RWC: Received Target Abort
    localparam PCI_Header__STS__RTA__ADDR = 'h61;
    localparam PCI_Header__STS__RTA__MASK = 'h10000000;
    localparam PCI_Header__STS__RTA__DFLT = 'h0;
// RWC: Signaled Target Abort
    localparam PCI_Header__STS__STA__ADDR = 'h61;
    localparam PCI_Header__STS__STA__MASK = 'h8000000;
    localparam PCI_Header__STS__STA__DFLT = 'h0;
// RO: PCI DEVSEL Timing
    localparam PCI_Header__STS__DEVT__ADDR = 'h61;
    localparam PCI_Header__STS__DEVT__MASK = 'h6000000;
    localparam PCI_Header__STS__DEVT__DFLT = 'h0;
// RWC: Master Data Parity Error Detected
    localparam PCI_Header__STS__DPD__ADDR = 'h61;
    localparam PCI_Header__STS__DPD__MASK = 'h1000000;
    localparam PCI_Header__STS__DPD__DFLT = 'h0;
// RO: Fast Back-To-Back Capable
    localparam PCI_Header__STS__FBC__ADDR = 'h61;
    localparam PCI_Header__STS__FBC__MASK = 'h800000;
    localparam PCI_Header__STS__FBC__DFLT = 'h0;
// RO: 66 MHz Capable
    localparam PCI_Header__STS__C66__ADDR = 'h61;
    localparam PCI_Header__STS__C66__MASK = 'h200000;
    localparam PCI_Header__STS__C66__DFLT = 'h0;
// RO: Capabilities List (PCI power management mandatory)
    localparam PCI_Header__STS__CL__ADDR = 'h61;
    localparam PCI_Header__STS__CL__MASK = 'h100000;
    localparam PCI_Header__STS__CL__DFLT = 'h100000;
// RO: Interrupt Status (1 - asserted)
    localparam PCI_Header__STS__IS__ADDR = 'h61;
    localparam PCI_Header__STS__IS__MASK = 'h80000;
    localparam PCI_Header__STS__IS__DFLT = 'h0;
// RO: HBA Revision ID
    localparam PCI_Header__RID__RID__ADDR = 'h62;
    localparam PCI_Header__RID__RID__MASK = 'hff;
    localparam PCI_Header__RID__RID__DFLT = 'h2;
// RO: Base Class Code: 1 - Mass Storage Device
    localparam PCI_Header__CC__BCC__ADDR = 'h62;
    localparam PCI_Header__CC__BCC__MASK = 'hff000000;
    localparam PCI_Header__CC__BCC__DFLT = 'h1000000;
// RO: Sub Class Code: 0x06 - SATA Device
    localparam PCI_Header__CC__SCC__ADDR = 'h62;
    localparam PCI_Header__CC__SCC__MASK = 'hff0000;
    localparam PCI_Header__CC__SCC__DFLT = 'h60000;
// RO: Programming Interface: 1 - AHCI HBA major rev 1
    localparam PCI_Header__CC__PI__ADDR = 'h62;
    localparam PCI_Header__CC__PI__MASK = 'hff0000;
    localparam PCI_Header__CC__PI__DFLT = 'h10000;
// RW: Cache Line Size
    localparam PCI_Header__CLS__CLS__ADDR = 'h63;
    localparam PCI_Header__CLS__CLS__MASK = 'hff;
    localparam PCI_Header__CLS__CLS__DFLT = 'h0;
// RW: Master Latency Timer
    localparam PCI_Header__MLT__MLT__ADDR = 'h63;
    localparam PCI_Header__MLT__MLT__MASK = 'hff00;
    localparam PCI_Header__MLT__MLT__DFLT = 'h0;
// RO: Multi-Function Device
    localparam PCI_Header__HTYPE__MFDT__ADDR = 'h63;
    localparam PCI_Header__HTYPE__MFDT__MASK = 'h8000;
    localparam PCI_Header__HTYPE__MFDT__DFLT = 'h0;
// RO: Header Layout 0 - HBA uses a target device layout
    localparam PCI_Header__HTYPE__HL__ADDR = 'h63;
    localparam PCI_Header__HTYPE__HL__MASK = 'h7f00;
    localparam PCI_Header__HTYPE__HL__DFLT = 'h0;
// RO: AHCI Base Address high bits, normally RW, but here RO to get to MAXIGP1 space
    localparam PCI_Header__ABAR__BA__ADDR = 'h69;
    localparam PCI_Header__ABAR__BA__MASK = 'hfffffff0;
    localparam PCI_Header__ABAR__BA__DFLT = 'h80000000;
// RO: Prefetchable (this is not)
    localparam PCI_Header__ABAR__PF__ADDR = 'h69;
    localparam PCI_Header__ABAR__PF__MASK = 'h8;
    localparam PCI_Header__ABAR__PF__DFLT = 'h0;
// RO: Type (0 - any 32-bit address, here it is hard-mapped
    localparam PCI_Header__ABAR__TP__ADDR = 'h69;
    localparam PCI_Header__ABAR__TP__MASK = 'h6;
    localparam PCI_Header__ABAR__TP__DFLT = 'h0;
// RO: Resource Type Indicator: 0 - memory address
    localparam PCI_Header__ABAR__RTE__ADDR = 'h69;
    localparam PCI_Header__ABAR__RTE__MASK = 'h1;
    localparam PCI_Header__ABAR__RTE__DFLT = 'h0;
// RO: SubSystem ID
    localparam PCI_Header__SS__SSID__ADDR = 'h6b;
    localparam PCI_Header__SS__SSID__MASK = 'hffff0000;
    localparam PCI_Header__SS__SSID__DFLT = 'h10000;
// RO: SubSystem Vendor ID
    localparam PCI_Header__SS__SSVID__ADDR = 'h6b;
    localparam PCI_Header__SS__SSVID__MASK = 'hffff;
    localparam PCI_Header__SS__SSVID__DFLT = 'hfffe;
// RO: ROM Base Address
    localparam PCI_Header__EROM__RBA__ADDR = 'h6c;
    localparam PCI_Header__EROM__RBA__MASK = 'hffffffff;
    localparam PCI_Header__EROM__RBA__DFLT = 'h0;
// RO: Capabilities pointer
    localparam PCI_Header__CAP__CAP__ADDR = 'h6d;
    localparam PCI_Header__CAP__CAP__MASK = 'hff;
    localparam PCI_Header__CAP__CAP__DFLT = 'h40;
// RO: Interrupt pin
    localparam PCI_Header__INTR__IPIN__ADDR = 'h6f;
    localparam PCI_Header__INTR__IPIN__MASK = 'hff00;
    localparam PCI_Header__INTR__IPIN__DFLT = 'h100;
// RW: Interrupt Line
    localparam PCI_Header__INTR__ILINE__ADDR = 'h6f;
    localparam PCI_Header__INTR__ILINE__MASK = 'hff;
    localparam PCI_Header__INTR__ILINE__DFLT = 'h0;
// RO: Minimal Grant
    localparam PCI_Header__MGNT__MGNT__ADDR = 'h6f;
    localparam PCI_Header__MGNT__MGNT__MASK = 'hff0000;
    localparam PCI_Header__MGNT__MGNT__DFLT = 'h0;
// RO: Maximal Latency
    localparam PCI_Header__MLAT__MLAT__ADDR = 'h6f;
    localparam PCI_Header__MLAT__MLAT__MASK = 'hff000000;
    localparam PCI_Header__MLAT__MLAT__DFLT = 'h0;
// RO: Next Capability pointer
    localparam PMCAP__PID__NEXT__ADDR = 'h70;
    localparam PMCAP__PID__NEXT__MASK = 'hff00;
    localparam PMCAP__PID__NEXT__DFLT = 'h0;
// RO: This is PCI Power Management Capability
    localparam PMCAP__PID__CID__ADDR = 'h70;
    localparam PMCAP__PID__CID__MASK = 'hff;
    localparam PMCAP__PID__CID__DFLT = 'h1;
// RO: PME_SUPPORT bits:'b01000
    localparam PMCAP__PC__PSUP__ADDR = 'h70;
    localparam PMCAP__PC__PSUP__MASK = 'hf8000000;
    localparam PMCAP__PC__PSUP__DFLT = 'h40000000;
// RO: D2 Support - no
    localparam PMCAP__PC__D2S__ADDR = 'h70;
    localparam PMCAP__PC__D2S__MASK = 'h4000000;
    localparam PMCAP__PC__D2S__DFLT = 'h0;
// RO: D1 Support - no
    localparam PMCAP__PC__D1S__ADDR = 'h70;
    localparam PMCAP__PC__D1S__MASK = 'h2000000;
    localparam PMCAP__PC__D1S__DFLT = 'h0;
// RO: Maximal D3cold current
    localparam PMCAP__PC__AUXC__ADDR = 'h70;
    localparam PMCAP__PC__AUXC__MASK = 'h1c00000;
    localparam PMCAP__PC__AUXC__DFLT = 'h0;
// RO: Device-specific initialization required
    localparam PMCAP__PC__DSI__ADDR = 'h70;
    localparam PMCAP__PC__DSI__MASK = 'h200000;
    localparam PMCAP__PC__DSI__DFLT = 'h0;
// RO: PCI clock required to generate PME
    localparam PMCAP__PC__PMEC__ADDR = 'h70;
    localparam PMCAP__PC__PMEC__MASK = 'h80000;
    localparam PMCAP__PC__PMEC__DFLT = 'h0;
// RO: Revision of Power Management Specification support version
    localparam PMCAP__PC__VS__ADDR = 'h70;
    localparam PMCAP__PC__VS__MASK = 'h70000;
    localparam PMCAP__PC__VS__DFLT = 'h0;
// RWC: PME Status, set by hardware when HBA generates PME
    localparam PMCAP__PMCS__PMES__ADDR = 'h71;
    localparam PMCAP__PMCS__PMES__MASK = 'h8000;
    localparam PMCAP__PMCS__PMES__DFLT = 'h0;
// RW: PME Enable
    localparam PMCAP__PMCS__PMEE__ADDR = 'h71;
    localparam PMCAP__PMCS__PMEE__MASK = 'h100;
    localparam PMCAP__PMCS__PMEE__DFLT = 'h0;
// RW: Power State
    localparam PMCAP__PMCS__PS__ADDR = 'h71;
    localparam PMCAP__PMCS__PS__MASK = 'h3;
    localparam PMCAP__PMCS__PS__DFLT = 'h0;
// RO: Supports 64-bit Addressing - no
    localparam GHC__CAP__S64A__ADDR = 'h0;
    localparam GHC__CAP__S64A__MASK = 'h80000000;
    localparam GHC__CAP__S64A__DFLT = 'h0;
// RO: Supports Native Command Queuing - no
    localparam GHC__CAP__SNCQ__ADDR = 'h0;
    localparam GHC__CAP__SNCQ__MASK = 'h40000000;
    localparam GHC__CAP__SNCQ__DFLT = 'h0;
// RO: Supports SNotification Register - no
    localparam GHC__CAP__SSNTF__ADDR = 'h0;
    localparam GHC__CAP__SSNTF__MASK = 'h20000000;
    localparam GHC__CAP__SSNTF__DFLT = 'h0;
// RO: Supports Mechanical Presence Switch - no
    localparam GHC__CAP__SMPS__ADDR = 'h0;
    localparam GHC__CAP__SMPS__MASK = 'h10000000;
    localparam GHC__CAP__SMPS__DFLT = 'h0;
// RO: Supports Staggered Spin-up - no
    localparam GHC__CAP__SSS__ADDR = 'h0;
    localparam GHC__CAP__SSS__MASK = 'h8000000;
    localparam GHC__CAP__SSS__DFLT = 'h0;
// RO: Supports Aggressive Link Power Management - no
    localparam GHC__CAP__SALP__ADDR = 'h0;
    localparam GHC__CAP__SALP__MASK = 'h4000000;
    localparam GHC__CAP__SALP__DFLT = 'h0;
// RO: Supports Activity LED - no
    localparam GHC__CAP__SAL__ADDR = 'h0;
    localparam GHC__CAP__SAL__MASK = 'h2000000;
    localparam GHC__CAP__SAL__DFLT = 'h0;
// RO: Supports Command List Override - no (not capable of clearing BSY and DRQ bits, needs soft reset
    localparam GHC__CAP__SCLO__ADDR = 'h0;
    localparam GHC__CAP__SCLO__MASK = 'h1000000;
    localparam GHC__CAP__SCLO__DFLT = 'h0;
// RO: Interface Maximal speed: 2 - Gen2, 3 - Gen3
    localparam GHC__CAP__ISS__ADDR = 'h0;
    localparam GHC__CAP__ISS__MASK = 'hf00000;
    localparam GHC__CAP__ISS__DFLT = 'h200000;
// RO: AHCI only (0 - legacy too)
    localparam GHC__CAP__SAM__ADDR = 'h0;
    localparam GHC__CAP__SAM__MASK = 'h40000;
    localparam GHC__CAP__SAM__DFLT = 'h40000;
// RO: Supports Port Multiplier - no
    localparam GHC__CAP__SPM__ADDR = 'h0;
    localparam GHC__CAP__SPM__MASK = 'h20000;
    localparam GHC__CAP__SPM__DFLT = 'h0;
// RO: Supports FIS-based switching of the Port Multiplier - no
    localparam GHC__CAP__FBSS__ADDR = 'h0;
    localparam GHC__CAP__FBSS__MASK = 'h10000;
    localparam GHC__CAP__FBSS__DFLT = 'h0;
// RO: PIO Multiple DRQ block - no
    localparam GHC__CAP__PMD__ADDR = 'h0;
    localparam GHC__CAP__PMD__MASK = 'h8000;
    localparam GHC__CAP__PMD__DFLT = 'h0;
// RO: Slumber State Capable - no
    localparam GHC__CAP__SSC__ADDR = 'h0;
    localparam GHC__CAP__SSC__MASK = 'h4000;
    localparam GHC__CAP__SSC__DFLT = 'h0;
// RO: Partial State Capable - no
    localparam GHC__CAP__PSC__ADDR = 'h0;
    localparam GHC__CAP__PSC__MASK = 'h2000;
    localparam GHC__CAP__PSC__DFLT = 'h0;
// RO: Number of Command Slots, 0-based (0 means 1?)
    localparam GHC__CAP__NSC__ADDR = 'h0;
    localparam GHC__CAP__NSC__MASK = 'h1f00;
    localparam GHC__CAP__NSC__DFLT = 'h0;
// RO: Command Completion Coalescing  - no
    localparam GHC__CAP__CCCS__ADDR = 'h0;
    localparam GHC__CAP__CCCS__MASK = 'h80;
    localparam GHC__CAP__CCCS__DFLT = 'h0;
// RO: Enclosure Management - no
    localparam GHC__CAP__EMS__ADDR = 'h0;
    localparam GHC__CAP__EMS__MASK = 'h40;
    localparam GHC__CAP__EMS__DFLT = 'h0;
// RO: External SATA connector - yes
    localparam GHC__CAP__SXS__ADDR = 'h0;
    localparam GHC__CAP__SXS__MASK = 'h20;
    localparam GHC__CAP__SXS__DFLT = 'h20;
// RO: Number of Ports, 0-based (0 means 1?)
    localparam GHC__CAP__NP__ADDR = 'h0;
    localparam GHC__CAP__NP__MASK = 'h1f;
    localparam GHC__CAP__NP__DFLT = 'h0;
// RO: AHCI enable (0 - legacy)
    localparam GHC__GHC__AE__ADDR = 'h1;
    localparam GHC__GHC__AE__MASK = 'h80000000;
    localparam GHC__GHC__AE__DFLT = 'h80000000;
// RO: MSI Revert to Single Message
    localparam GHC__GHC__MRSM__ADDR = 'h1;
    localparam GHC__GHC__MRSM__MASK = 'h4;
    localparam GHC__GHC__MRSM__DFLT = 'h0;
// RW: Interrupt Enable (all ports)
    localparam GHC__GHC__IE__ADDR = 'h1;
    localparam GHC__GHC__IE__MASK = 'h2;
    localparam GHC__GHC__IE__DFLT = 'h0;
// RW1: HBA reset (COMINIT, ...). Set by software, cleared by hardware, section 10.4.3
    localparam GHC__GHC__HR__ADDR = 'h1;
    localparam GHC__GHC__HR__MASK = 'h1;
    localparam GHC__GHC__HR__DFLT = 'h0;
// RWC: Interrupt Pending Status (per port)
    localparam GHC__IS__IPS__ADDR = 'h2;
    localparam GHC__IS__IPS__MASK = 'hffffffff;
    localparam GHC__IS__IPS__DFLT = 'h0;
// RO: Ports Implemented
    localparam GHC__PI__PI__ADDR = 'h3;
    localparam GHC__PI__PI__MASK = 'hffffffff;
    localparam GHC__PI__PI__DFLT = 'h1;
// RO: AHCI Major Version 1.
    localparam GHC__VS__MJR__ADDR = 'h4;
    localparam GHC__VS__MJR__MASK = 'hffff0000;
    localparam GHC__VS__MJR__DFLT = 'h10000;
// RO: AHCI Minor Version 3.1
    localparam GHC__VS__MNR__ADDR = 'h4;
    localparam GHC__VS__MNR__MASK = 'hffff;
    localparam GHC__VS__MNR__DFLT = 'h301;
// RO: DevSleep Entrance from Slumber Only
    localparam GHC__CAP2__DESO__ADDR = 'h9;
    localparam GHC__CAP2__DESO__MASK = 'h20;
    localparam GHC__CAP2__DESO__DFLT = 'h0;
// RO: Supports Aggressive Device Sleep Management
    localparam GHC__CAP2__SADM__ADDR = 'h9;
    localparam GHC__CAP2__SADM__MASK = 'h10;
    localparam GHC__CAP2__SADM__DFLT = 'h0;
// RO: Supports Device Sleep
    localparam GHC__CAP2__SDS__ADDR = 'h9;
    localparam GHC__CAP2__SDS__MASK = 'h8;
    localparam GHC__CAP2__SDS__DFLT = 'h0;
// RO: Automatic Partial to Slumber Transitions
    localparam GHC__CAP2__APST__ADDR = 'h9;
    localparam GHC__CAP2__APST__MASK = 'h4;
    localparam GHC__CAP2__APST__DFLT = 'h0;
// RO: NVMHCI Present (section 10.15)
    localparam GHC__CAP2__NVMP__ADDR = 'h9;
    localparam GHC__CAP2__NVMP__MASK = 'h2;
    localparam GHC__CAP2__NVMP__DFLT = 'h0;
// RO: BIOS/OS Handoff - not supported
    localparam GHC__CAP2__BOH__ADDR = 'h9;
    localparam GHC__CAP2__BOH__MASK = 'h1;
    localparam GHC__CAP2__BOH__DFLT = 'h0;
// RW: Command List Base Address (1KB aligned)
    localparam HBA_PORT__PxCLB__CLB__ADDR = 'h40;
    localparam HBA_PORT__PxCLB__CLB__MASK = 'hfffffc00;
    localparam HBA_PORT__PxCLB__CLB__DFLT = 'h80000800;
// RW: Command List Base Address (1KB aligned)
    localparam HBA_PORT__PxFB__CLB__ADDR = 'h42;
    localparam HBA_PORT__PxFB__CLB__MASK = 'hffffff00;
    localparam HBA_PORT__PxFB__CLB__DFLT = 'h80000c00;
// RWC: Cold Port Detect Status
    localparam HBA_PORT__PxIS__CPDS__ADDR = 'h44;
    localparam HBA_PORT__PxIS__CPDS__MASK = 'h80000000;
    localparam HBA_PORT__PxIS__CPDS__DFLT = 'h0;
// RWC: Task File Error Status
    localparam HBA_PORT__PxIS__TFES__ADDR = 'h44;
    localparam HBA_PORT__PxIS__TFES__MASK = 'h40000000;
    localparam HBA_PORT__PxIS__TFES__DFLT = 'h0;
// RWC: Host Bus (PCI) Fatal error
    localparam HBA_PORT__PxIS__HBFS__ADDR = 'h44;
    localparam HBA_PORT__PxIS__HBFS__MASK = 'h20000000;
    localparam HBA_PORT__PxIS__HBFS__DFLT = 'h0;
// RWC: ECC error R/W system memory
    localparam HBA_PORT__PxIS__HBDS__ADDR = 'h44;
    localparam HBA_PORT__PxIS__HBDS__MASK = 'h10000000;
    localparam HBA_PORT__PxIS__HBDS__DFLT = 'h0;
// RWC: Interface Fatal Error Status (sect. 6.1.2)
    localparam HBA_PORT__PxIS__IFS__ADDR = 'h44;
    localparam HBA_PORT__PxIS__IFS__MASK = 'h8000000;
    localparam HBA_PORT__PxIS__IFS__DFLT = 'h0;
// RWC: Interface Non-Fatal Error Status (sect. 6.1.2)
    localparam HBA_PORT__PxIS__INFS__ADDR = 'h44;
    localparam HBA_PORT__PxIS__INFS__MASK = 'h4000000;
    localparam HBA_PORT__PxIS__INFS__DFLT = 'h0;
// RWC: Overflow Status
    localparam HBA_PORT__PxIS__OFS__ADDR = 'h44;
    localparam HBA_PORT__PxIS__OFS__MASK = 'h1000000;
    localparam HBA_PORT__PxIS__OFS__DFLT = 'h0;
// RWC: Incorrect Port Multiplier Status
    localparam HBA_PORT__PxIS__IPMS__ADDR = 'h44;
    localparam HBA_PORT__PxIS__IPMS__MASK = 'h800000;
    localparam HBA_PORT__PxIS__IPMS__DFLT = 'h0;
// RO: PhyRdy changed Status
    localparam HBA_PORT__PxIS__PRCS__ADDR = 'h44;
    localparam HBA_PORT__PxIS__PRCS__MASK = 'h400000;
    localparam HBA_PORT__PxIS__PRCS__DFLT = 'h0;
// RWC: Device Mechanical Presence Status
    localparam HBA_PORT__PxIS__DMPS__ADDR = 'h44;
    localparam HBA_PORT__PxIS__DMPS__MASK = 'h80;
    localparam HBA_PORT__PxIS__DMPS__DFLT = 'h0;
// RO: Port Connect Change Status
    localparam HBA_PORT__PxIS__PCS__ADDR = 'h44;
    localparam HBA_PORT__PxIS__PCS__MASK = 'h40;
    localparam HBA_PORT__PxIS__PCS__DFLT = 'h0;
// RWC: Descriptor Processed
    localparam HBA_PORT__PxIS__DPS__ADDR = 'h44;
    localparam HBA_PORT__PxIS__DPS__MASK = 'h20;
    localparam HBA_PORT__PxIS__DPS__DFLT = 'h0;
// RO: Unknown FIS
    localparam HBA_PORT__PxIS__UFS__ADDR = 'h44;
    localparam HBA_PORT__PxIS__UFS__MASK = 'h10;
    localparam HBA_PORT__PxIS__UFS__DFLT = 'h0;
// RWC: Set Device Bits Interrupt - Set Device bits FIS with 'I' bit set
    localparam HBA_PORT__PxIS__SDBS__ADDR = 'h44;
    localparam HBA_PORT__PxIS__SDBS__MASK = 'h8;
    localparam HBA_PORT__PxIS__SDBS__DFLT = 'h0;
// RWC: DMA Setup FIS Interrupt - DMA Setup FIS received with 'I' bit set
    localparam HBA_PORT__PxIS__DSS__ADDR = 'h44;
    localparam HBA_PORT__PxIS__DSS__MASK = 'h4;
    localparam HBA_PORT__PxIS__DSS__DFLT = 'h0;
// RWC: PIO Setup FIS Interrupt - PIO Setup FIS received with 'I' bit set
    localparam HBA_PORT__PxIS__PSS__ADDR = 'h44;
    localparam HBA_PORT__PxIS__PSS__MASK = 'h2;
    localparam HBA_PORT__PxIS__PSS__DFLT = 'h0;
// RWC: D2H Register FIS Interrupt - D2H Register FIS received with 'I' bit set
    localparam HBA_PORT__PxIS__DHRS__ADDR = 'h44;
    localparam HBA_PORT__PxIS__DHRS__MASK = 'h1;
    localparam HBA_PORT__PxIS__DHRS__DFLT = 'h0;
// RW: Cold Port Detect Enable
    localparam HBA_PORT__PxIE__CPDE__ADDR = 'h45;
    localparam HBA_PORT__PxIE__CPDE__MASK = 'h80000000;
    localparam HBA_PORT__PxIE__CPDE__DFLT = 'h0;
// RW: Task File Error Enable
    localparam HBA_PORT__PxIE__TFEE__ADDR = 'h45;
    localparam HBA_PORT__PxIE__TFEE__MASK = 'h40000000;
    localparam HBA_PORT__PxIE__TFEE__DFLT = 'h0;
// RW: Host Bus (PCI) Fatal Error Enable
    localparam HBA_PORT__PxIE__HBFE__ADDR = 'h45;
    localparam HBA_PORT__PxIE__HBFE__MASK = 'h20000000;
    localparam HBA_PORT__PxIE__HBFE__DFLT = 'h0;
// RW: ECC Error R/W System Memory Enable
    localparam HBA_PORT__PxIE__HBDE__ADDR = 'h45;
    localparam HBA_PORT__PxIE__HBDE__MASK = 'h10000000;
    localparam HBA_PORT__PxIE__HBDE__DFLT = 'h0;
// RW: Interface Fatal Error Enable (sect. 6.1.2)
    localparam HBA_PORT__PxIE__IFE__ADDR = 'h45;
    localparam HBA_PORT__PxIE__IFE__MASK = 'h8000000;
    localparam HBA_PORT__PxIE__IFE__DFLT = 'h0;
// RW: Interface Non-Fatal Error Enable (sect. 6.1.2)
    localparam HBA_PORT__PxIE__INFE__ADDR = 'h45;
    localparam HBA_PORT__PxIE__INFE__MASK = 'h4000000;
    localparam HBA_PORT__PxIE__INFE__DFLT = 'h0;
// RW: Overflow Enable
    localparam HBA_PORT__PxIE__OFE__ADDR = 'h45;
    localparam HBA_PORT__PxIE__OFE__MASK = 'h1000000;
    localparam HBA_PORT__PxIE__OFE__DFLT = 'h0;
// RW: Incorrect Port Multiplier Enable
    localparam HBA_PORT__PxIE__IPME__ADDR = 'h45;
    localparam HBA_PORT__PxIE__IPME__MASK = 'h800000;
    localparam HBA_PORT__PxIE__IPME__DFLT = 'h0;
// RW: PhyRdy changed Enable
    localparam HBA_PORT__PxIE__PRCE__ADDR = 'h45;
    localparam HBA_PORT__PxIE__PRCE__MASK = 'h400000;
    localparam HBA_PORT__PxIE__PRCE__DFLT = 'h0;
// RO: Device Mechanical Presence Interrupt Enable
    localparam HBA_PORT__PxIE__DMPE__ADDR = 'h45;
    localparam HBA_PORT__PxIE__DMPE__MASK = 'h80;
    localparam HBA_PORT__PxIE__DMPE__DFLT = 'h0;
// RW: Port Connect Change Interrupt Enable
    localparam HBA_PORT__PxIE__PCE__ADDR = 'h45;
    localparam HBA_PORT__PxIE__PCE__MASK = 'h40;
    localparam HBA_PORT__PxIE__PCE__DFLT = 'h0;
// RW: Descriptor Processed Interrupt Enable
    localparam HBA_PORT__PxIE__DPE__ADDR = 'h45;
    localparam HBA_PORT__PxIE__DPE__MASK = 'h20;
    localparam HBA_PORT__PxIE__DPE__DFLT = 'h0;
// RW: Unknown FIS
    localparam HBA_PORT__PxIE__UFE__ADDR = 'h45;
    localparam HBA_PORT__PxIE__UFE__MASK = 'h10;
    localparam HBA_PORT__PxIE__UFE__DFLT = 'h0;
// RW: Device Bits Interrupt Enable
    localparam HBA_PORT__PxIE__SDBE__ADDR = 'h45;
    localparam HBA_PORT__PxIE__SDBE__MASK = 'h8;
    localparam HBA_PORT__PxIE__SDBE__DFLT = 'h0;
// RW: DMA Setup FIS Interrupt Enable
    localparam HBA_PORT__PxIE__DSE__ADDR = 'h45;
    localparam HBA_PORT__PxIE__DSE__MASK = 'h4;
    localparam HBA_PORT__PxIE__DSE__DFLT = 'h0;
// RW: PIO Setup FIS Interrupt Enable
    localparam HBA_PORT__PxIE__PSE__ADDR = 'h45;
    localparam HBA_PORT__PxIE__PSE__MASK = 'h2;
    localparam HBA_PORT__PxIE__PSE__DFLT = 'h0;
// RW: D2H Register FIS Interrupt Enable
    localparam HBA_PORT__PxIE__DHRE__ADDR = 'h45;
    localparam HBA_PORT__PxIE__DHRE__MASK = 'h1;
    localparam HBA_PORT__PxIE__DHRE__DFLT = 'h0;
// RW: Interface Communication Control
    localparam HBA_PORT__PxCMD__ICC__ADDR = 'h46;
    localparam HBA_PORT__PxCMD__ICC__MASK = 'hf0000000;
    localparam HBA_PORT__PxCMD__ICC__DFLT = 'h0;
// RO: Aggressive Slumber/Partial - not implemented
    localparam HBA_PORT__PxCMD__ASP__ADDR = 'h46;
    localparam HBA_PORT__PxCMD__ASP__MASK = 'h8000000;
    localparam HBA_PORT__PxCMD__ASP__DFLT = 'h0;
// RO: Aggressive Link Power Management Enable - not implemented
    localparam HBA_PORT__PxCMD__ALPE__ADDR = 'h46;
    localparam HBA_PORT__PxCMD__ALPE__MASK = 'h4000000;
    localparam HBA_PORT__PxCMD__ALPE__DFLT = 'h0;
// RW: Drive LED on ATAPI enable
    localparam HBA_PORT__PxCMD__DLAE__ADDR = 'h46;
    localparam HBA_PORT__PxCMD__DLAE__MASK = 'h2000000;
    localparam HBA_PORT__PxCMD__DLAE__DFLT = 'h0;
// RW: Device is ATAPI (for activity LED)
    localparam HBA_PORT__PxCMD__ATAPI__ADDR = 'h46;
    localparam HBA_PORT__PxCMD__ATAPI__MASK = 'h1000000;
    localparam HBA_PORT__PxCMD__ATAPI__DFLT = 'h0;
// RW: Automatic Partial to Slumber Transitions Enabled
    localparam HBA_PORT__PxCMD__APSTE__ADDR = 'h46;
    localparam HBA_PORT__PxCMD__APSTE__MASK = 'h800000;
    localparam HBA_PORT__PxCMD__APSTE__DFLT = 'h0;
// RO: FIS-Based Switching Capable Port - not implemented
    localparam HBA_PORT__PxCMD__FBSCP__ADDR = 'h46;
    localparam HBA_PORT__PxCMD__FBSCP__MASK = 'h400000;
    localparam HBA_PORT__PxCMD__FBSCP__DFLT = 'h0;
// RO: External SATA port
    localparam HBA_PORT__PxCMD__ESP__ADDR = 'h46;
    localparam HBA_PORT__PxCMD__ESP__MASK = 'h200000;
    localparam HBA_PORT__PxCMD__ESP__DFLT = 'h200000;
// RO: Cold Presence Detection
    localparam HBA_PORT__PxCMD__CPD__ADDR = 'h46;
    localparam HBA_PORT__PxCMD__CPD__MASK = 'h100000;
    localparam HBA_PORT__PxCMD__CPD__DFLT = 'h0;
// RO: Mechanical Presence Switch Attached to Port
    localparam HBA_PORT__PxCMD__MPSP__ADDR = 'h46;
    localparam HBA_PORT__PxCMD__MPSP__MASK = 'h80000;
    localparam HBA_PORT__PxCMD__MPSP__DFLT = 'h0;
// RO: Hot Plug Capable Port
    localparam HBA_PORT__PxCMD__HPCP__ADDR = 'h46;
    localparam HBA_PORT__PxCMD__HPCP__MASK = 'h40000;
    localparam HBA_PORT__PxCMD__HPCP__DFLT = 'h40000;
// RW: Port Multiplier Attached - not implemented (software should write this bit)
    localparam HBA_PORT__PxCMD__PMA__ADDR = 'h46;
    localparam HBA_PORT__PxCMD__PMA__MASK = 'h20000;
    localparam HBA_PORT__PxCMD__PMA__DFLT = 'h0;
// RO: Cold Presence State
    localparam HBA_PORT__PxCMD__CPS__ADDR = 'h46;
    localparam HBA_PORT__PxCMD__CPS__MASK = 'h10000;
    localparam HBA_PORT__PxCMD__CPS__DFLT = 'h0;
// RO: Command List Running (section 5.3.2)
    localparam HBA_PORT__PxCMD__CR__ADDR = 'h46;
    localparam HBA_PORT__PxCMD__CR__MASK = 'h8000;
    localparam HBA_PORT__PxCMD__CR__DFLT = 'h0;
// RO: FIS Receive Running (section 10.3.2)
    localparam HBA_PORT__PxCMD__FR__ADDR = 'h46;
    localparam HBA_PORT__PxCMD__FR__MASK = 'h4000;
    localparam HBA_PORT__PxCMD__FR__DFLT = 'h0;
// RO: Mechanical Presence Switch State
    localparam HBA_PORT__PxCMD__MPSS__ADDR = 'h46;
    localparam HBA_PORT__PxCMD__MPSS__MASK = 'h2000;
    localparam HBA_PORT__PxCMD__MPSS__DFLT = 'h0;
// RO: Current Command Slot (when PxCMD.ST 1-> ) should be reset to 0, when 0->1 - highest priority is 0
    localparam HBA_PORT__PxCMD__CCS__ADDR = 'h46;
    localparam HBA_PORT__PxCMD__CCS__MASK = 'h1f00;
    localparam HBA_PORT__PxCMD__CCS__DFLT = 'h0;
// RW: FIS Receive Enable (enable after FIS memory is set)
    localparam HBA_PORT__PxCMD__FRE__ADDR = 'h46;
    localparam HBA_PORT__PxCMD__FRE__MASK = 'h10;
    localparam HBA_PORT__PxCMD__FRE__DFLT = 'h0;
// RW1: Command List Override
    localparam HBA_PORT__PxCMD__CLO__ADDR = 'h46;
    localparam HBA_PORT__PxCMD__CLO__MASK = 'h8;
    localparam HBA_PORT__PxCMD__CLO__DFLT = 'h0;
// RO: Power On Device (RW with Cold Presence Detection)
    localparam HBA_PORT__PxCMD__POD__ADDR = 'h46;
    localparam HBA_PORT__PxCMD__POD__MASK = 'h4;
    localparam HBA_PORT__PxCMD__POD__DFLT = 'h4;
// RO: Spin-Up Device (RW with Staggered Spin-Up Support)
    localparam HBA_PORT__PxCMD__SUD__ADDR = 'h46;
    localparam HBA_PORT__PxCMD__SUD__MASK = 'h2;
    localparam HBA_PORT__PxCMD__SUD__DFLT = 'h2;
// RW: Start (HBA may process commands). See section 10.3.1
    localparam HBA_PORT__PxCMD__ST__ADDR = 'h46;
    localparam HBA_PORT__PxCMD__ST__MASK = 'h1;
    localparam HBA_PORT__PxCMD__ST__DFLT = 'h0;
// RO: Latest Copy of Task File Error Register
    localparam HBA_PORT__PxTFD__ERR__ADDR = 'h48;
    localparam HBA_PORT__PxTFD__ERR__MASK = 'hff00;
    localparam HBA_PORT__PxTFD__ERR__DFLT = 'h0;
// RO: Latest Copy of Task File Status Register: BSY
    localparam HBA_PORT__PxTFD__STS__BSY__ADDR = 'h48;
    localparam HBA_PORT__PxTFD__STS__BSY__MASK = 'h80;
    localparam HBA_PORT__PxTFD__STS__BSY__DFLT = 'h0;
// RO: Latest Copy of Task File Status Register: command-specific bits 4..6 
    localparam HBA_PORT__PxTFD__STS__64__ADDR = 'h48;
    localparam HBA_PORT__PxTFD__STS__64__MASK = 'h70;
    localparam HBA_PORT__PxTFD__STS__64__DFLT = 'h0;
// RO: Latest Copy of Task File Status Register: DRQ
    localparam HBA_PORT__PxTFD__STS__DRQ__ADDR = 'h48;
    localparam HBA_PORT__PxTFD__STS__DRQ__MASK = 'h8;
    localparam HBA_PORT__PxTFD__STS__DRQ__DFLT = 'h0;
// RO: Latest Copy of Task File Status Register: command-specific bits 1..2 
    localparam HBA_PORT__PxTFD__STS__12__ADDR = 'h48;
    localparam HBA_PORT__PxTFD__STS__12__MASK = 'h6;
    localparam HBA_PORT__PxTFD__STS__12__DFLT = 'h0;
// RO: Latest Copy of Task File Status Register: ERR
    localparam HBA_PORT__PxTFD__STS__ERR__ADDR = 'h48;
    localparam HBA_PORT__PxTFD__STS__ERR__MASK = 'h1;
    localparam HBA_PORT__PxTFD__STS__ERR__DFLT = 'h0;
// RO: Data in the first D2H Register FIS
    localparam HBA_PORT__PxSIG__SIG__ADDR = 'h49;
    localparam HBA_PORT__PxSIG__SIG__MASK = 'hffffffff;
    localparam HBA_PORT__PxSIG__SIG__DFLT = 'hffffffff;
// RO: Interface Power Management
    localparam HBA_PORT__PxSSTS__IPM__ADDR = 'h4a;
    localparam HBA_PORT__PxSSTS__IPM__MASK = 'hf00;
    localparam HBA_PORT__PxSSTS__IPM__DFLT = 'h0;
// RO: Interface Speed
    localparam HBA_PORT__PxSSTS__SPD__ADDR = 'h4a;
    localparam HBA_PORT__PxSSTS__SPD__MASK = 'hf0;
    localparam HBA_PORT__PxSSTS__SPD__DFLT = 'h0;
// RO: Device Detection (should be detected if COMINIT is received)
    localparam HBA_PORT__PxSSTS__DET__ADDR = 'h4a;
    localparam HBA_PORT__PxSSTS__DET__MASK = 'hf;
    localparam HBA_PORT__PxSSTS__DET__DFLT = 'h0;
// RO: Port Multiplier Port - not used by AHCI
    localparam HBA_PORT__PxSCTL__PMP__ADDR = 'h4b;
    localparam HBA_PORT__PxSCTL__PMP__MASK = 'hf0000;
    localparam HBA_PORT__PxSCTL__PMP__DFLT = 'h0;
// RO: Select Power Management - not used by AHCI
    localparam HBA_PORT__PxSCTL__SPM__ADDR = 'h4b;
    localparam HBA_PORT__PxSCTL__SPM__MASK = 'hf000;
    localparam HBA_PORT__PxSCTL__SPM__DFLT = 'h0;
// RW: Interface Power Management Transitions Allowed
    localparam HBA_PORT__PxSCTL__IPM__ADDR = 'h4b;
    localparam HBA_PORT__PxSCTL__IPM__MASK = 'hf00;
    localparam HBA_PORT__PxSCTL__IPM__DFLT = 'h0;
// RW: Interface Highest Speed
    localparam HBA_PORT__PxSCTL__SPD__ADDR = 'h4b;
    localparam HBA_PORT__PxSCTL__SPD__MASK = 'hf0;
    localparam HBA_PORT__PxSCTL__SPD__DFLT = 'h0;
// RW: Device Detection Initialization
    localparam HBA_PORT__PxSCTL__DET__ADDR = 'h4b;
    localparam HBA_PORT__PxSCTL__DET__MASK = 'hf;
    localparam HBA_PORT__PxSCTL__DET__DFLT = 'h0;
// RWC: Exchanged (set on COMINIT), reflected in PxIS.PCS
    localparam HBA_PORT__PxSERR__DIAG__X__ADDR = 'h4c;
    localparam HBA_PORT__PxSERR__DIAG__X__MASK = 'h4000000;
    localparam HBA_PORT__PxSERR__DIAG__X__DFLT = 'h0;
// RWC: Unknown FIS
    localparam HBA_PORT__PxSERR__DIAG__F__ADDR = 'h4c;
    localparam HBA_PORT__PxSERR__DIAG__F__MASK = 'h2000000;
    localparam HBA_PORT__PxSERR__DIAG__F__DFLT = 'h0;
// RWC: Transport state transition error
    localparam HBA_PORT__PxSERR__DIAG__T__ADDR = 'h4c;
    localparam HBA_PORT__PxSERR__DIAG__T__MASK = 'h1000000;
    localparam HBA_PORT__PxSERR__DIAG__T__DFLT = 'h0;
// RWC: Link sequence error
    localparam HBA_PORT__PxSERR__DIAG__S__ADDR = 'h4c;
    localparam HBA_PORT__PxSERR__DIAG__S__MASK = 'h800000;
    localparam HBA_PORT__PxSERR__DIAG__S__DFLT = 'h0;
// RWC: Handshake Error (i.e. Device got CRC error)
    localparam HBA_PORT__PxSERR__DIAG__H__ADDR = 'h4c;
    localparam HBA_PORT__PxSERR__DIAG__H__MASK = 'h400000;
    localparam HBA_PORT__PxSERR__DIAG__H__DFLT = 'h0;
// RWC: CRC error in Link layer
    localparam HBA_PORT__PxSERR__DIAG__C__ADDR = 'h4c;
    localparam HBA_PORT__PxSERR__DIAG__C__MASK = 'h200000;
    localparam HBA_PORT__PxSERR__DIAG__C__DFLT = 'h0;
// RWC: Disparity Error - not used by AHCI
    localparam HBA_PORT__PxSERR__DIAG__D__ADDR = 'h4c;
    localparam HBA_PORT__PxSERR__DIAG__D__MASK = 'h100000;
    localparam HBA_PORT__PxSERR__DIAG__D__DFLT = 'h0;
// RWC: 10B to 8B decode error
    localparam HBA_PORT__PxSERR__DIAG__B__ADDR = 'h4c;
    localparam HBA_PORT__PxSERR__DIAG__B__MASK = 'h80000;
    localparam HBA_PORT__PxSERR__DIAG__B__DFLT = 'h0;
// RWC: COMMWAKE signal was detected
    localparam HBA_PORT__PxSERR__DIAG__W__ADDR = 'h4c;
    localparam HBA_PORT__PxSERR__DIAG__W__MASK = 'h40000;
    localparam HBA_PORT__PxSERR__DIAG__W__DFLT = 'h0;
// RWC: PHY Internal Error
    localparam HBA_PORT__PxSERR__DIAG__I__ADDR = 'h4c;
    localparam HBA_PORT__PxSERR__DIAG__I__MASK = 'h20000;
    localparam HBA_PORT__PxSERR__DIAG__I__DFLT = 'h0;
// RWC: PhyRdy changed. Reflected in PxIS.PRCS bit.
    localparam HBA_PORT__PxSERR__DIAG__N__ADDR = 'h4c;
    localparam HBA_PORT__PxSERR__DIAG__N__MASK = 'h10000;
    localparam HBA_PORT__PxSERR__DIAG__N__DFLT = 'h0;
// RWC: Internal Error
    localparam HBA_PORT__PxSERR__ERR__E__ADDR = 'h4c;
    localparam HBA_PORT__PxSERR__ERR__E__MASK = 'h800;
    localparam HBA_PORT__PxSERR__ERR__E__DFLT = 'h0;
// RWC: Protocol Error - a violation of SATA protocol detected
    localparam HBA_PORT__PxSERR__ERR__P__ADDR = 'h4c;
    localparam HBA_PORT__PxSERR__ERR__P__MASK = 'h400;
    localparam HBA_PORT__PxSERR__ERR__P__DFLT = 'h0;
// RWC: Persistent Communication or Data Integrity Error
    localparam HBA_PORT__PxSERR__ERR__C__ADDR = 'h4c;
    localparam HBA_PORT__PxSERR__ERR__C__MASK = 'h200;
    localparam HBA_PORT__PxSERR__ERR__C__DFLT = 'h0;
// RWC: Transient Data Integrity Error (error not recovered by the interface)
    localparam HBA_PORT__PxSERR__ERR__T__ADDR = 'h4c;
    localparam HBA_PORT__PxSERR__ERR__T__MASK = 'h100;
    localparam HBA_PORT__PxSERR__ERR__T__DFLT = 'h0;
// RWC: Communication between the device and host was lost but re-established
    localparam HBA_PORT__PxSERR__ERR__M__ADDR = 'h4c;
    localparam HBA_PORT__PxSERR__ERR__M__MASK = 'h2;
    localparam HBA_PORT__PxSERR__ERR__M__DFLT = 'h0;
// RWC: Recovered Data integrity Error
    localparam HBA_PORT__PxSERR__ERR__I__ADDR = 'h4c;
    localparam HBA_PORT__PxSERR__ERR__I__MASK = 'h1;
    localparam HBA_PORT__PxSERR__ERR__I__DFLT = 'h0;
// RW1: Device Status: bit per Port, for TAG in native queued command
    localparam HBA_PORT__PxSACT__DS__ADDR = 'h4d;
    localparam HBA_PORT__PxSACT__DS__MASK = 'hffffffff;
    localparam HBA_PORT__PxSACT__DS__DFLT = 'h0;
// RW1: Command Issued: bit per Port, only set when PxCMD.ST==1, also cleared by PxCMD.ST: 1->0 by soft
    localparam HBA_PORT__PxCI__CI__ADDR = 'h4e;
    localparam HBA_PORT__PxCI__CI__MASK = 'hffffffff;
    localparam HBA_PORT__PxCI__CI__DFLT = 'h0;
// RWC: PM Notify (bit per PM port)
    localparam HBA_PORT__PxSNTF__PMN__ADDR = 'h4f;
    localparam HBA_PORT__PxSNTF__PMN__MASK = 'hffff;
    localparam HBA_PORT__PxSNTF__PMN__DFLT = 'h0;
// RO: Device with Error
    localparam HBA_PORT__PxFBS__DWE__ADDR = 'h50;
    localparam HBA_PORT__PxFBS__DWE__MASK = 'hf0000;
    localparam HBA_PORT__PxFBS__DWE__DFLT = 'h0;
// RO: Active Device Optimization
    localparam HBA_PORT__PxFBS__ADO__ADDR = 'h50;
    localparam HBA_PORT__PxFBS__ADO__MASK = 'hf000;
    localparam HBA_PORT__PxFBS__ADO__DFLT = 'h0;
// RW: Device To Issue
    localparam HBA_PORT__PxFBS__DEV__ADDR = 'h50;
    localparam HBA_PORT__PxFBS__DEV__MASK = 'hf00;
    localparam HBA_PORT__PxFBS__DEV__DFLT = 'h0;
// RO: Single Device Error
    localparam HBA_PORT__PxFBS__SDE__ADDR = 'h50;
    localparam HBA_PORT__PxFBS__SDE__MASK = 'h4;
    localparam HBA_PORT__PxFBS__SDE__DFLT = 'h0;
// RW1: Device Error Clear
    localparam HBA_PORT__PxFBS__DEC__ADDR = 'h50;
    localparam HBA_PORT__PxFBS__DEC__MASK = 'h2;
    localparam HBA_PORT__PxFBS__DEC__DFLT = 'h0;
// RW: Enable
    localparam HBA_PORT__PxFBS__EN__ADDR = 'h50;
    localparam HBA_PORT__PxFBS__EN__MASK = 'h1;
    localparam HBA_PORT__PxFBS__EN__DFLT = 'h0;
// RO: DITO Multiplier
    localparam HBA_PORT__PxDEVSLP__DM__ADDR = 'h51;
    localparam HBA_PORT__PxDEVSLP__DM__MASK = 'h1e000000;
    localparam HBA_PORT__PxDEVSLP__DM__DFLT = 'h0;
// RW: Device Sleep Idle Timeout (section 8.5.1.1.1)
    localparam HBA_PORT__PxDEVSLP__DITO__ADDR = 'h51;
    localparam HBA_PORT__PxDEVSLP__DITO__MASK = 'h1ff8000;
    localparam HBA_PORT__PxDEVSLP__DITO__DFLT = 'h0;
// RW: Minimum Device Sleep Assertion Time
    localparam HBA_PORT__PxDEVSLP__MDAT__ADDR = 'h51;
    localparam HBA_PORT__PxDEVSLP__MDAT__MASK = 'h7c00;
    localparam HBA_PORT__PxDEVSLP__MDAT__DFLT = 'h0;
// RW: Device Sleep Exit Timeout
    localparam HBA_PORT__PxDEVSLP__DETO__ADDR = 'h51;
    localparam HBA_PORT__PxDEVSLP__DETO__MASK = 'h3fc;
    localparam HBA_PORT__PxDEVSLP__DETO__DFLT = 'h0;
// RO: Device Sleep Present
    localparam HBA_PORT__PxDEVSLP__DSP__ADDR = 'h51;
    localparam HBA_PORT__PxDEVSLP__DSP__MASK = 'h2;
    localparam HBA_PORT__PxDEVSLP__DSP__DFLT = 'h0;
// RO: Aggressive Device Sleep Enable
    localparam HBA_PORT__PxDEVSLP__ADSE__ADDR = 'h51;
    localparam HBA_PORT__PxDEVSLP__ADSE__MASK = 'h1;
    localparam HBA_PORT__PxDEVSLP__ADSE__DFLT = 'h0;
// RW: SAXIHP write channel cache mode 
    localparam HBA_PORT__AFI_CACHE__WR_CM__ADDR = 'h5c;
    localparam HBA_PORT__AFI_CACHE__WR_CM__MASK = 'hf0;
    localparam HBA_PORT__AFI_CACHE__WR_CM__DFLT = 'h30;
// RW: SAXIHP read channel cache mode 
    localparam HBA_PORT__AFI_CACHE__RD_CM__ADDR = 'h5c;
    localparam HBA_PORT__AFI_CACHE__RD_CM__MASK = 'hf;
    localparam HBA_PORT__AFI_CACHE__RD_CM__DFLT = 'h3;
// RW: Address/not data for programming AHCI state machine
    localparam HBA_PORT__PGM_AHCI_SM__AnD__ADDR = 'h5d;
    localparam HBA_PORT__PGM_AHCI_SM__AnD__MASK = 'h1000000;
    localparam HBA_PORT__PGM_AHCI_SM__AnD__DFLT = 'h0;
// RW: Program address/data for programming AHCI state machine
    localparam HBA_PORT__PGM_AHCI_SM__PGM_AD__ADDR = 'h5d;
    localparam HBA_PORT__PGM_AHCI_SM__PGM_AD__MASK = 'h3ffff;
    localparam HBA_PORT__PGM_AHCI_SM__PGM_AD__DFLT = 'h0;
// RW: 3-bit tag to add to the recorded timestamp
    localparam HBA_PORT__PunchTime__TAG__ADDR = 'h5e;
    localparam HBA_PORT__PunchTime__TAG__MASK = 'h7;
    localparam HBA_PORT__PunchTime__TAG__DFLT = 'h0;

