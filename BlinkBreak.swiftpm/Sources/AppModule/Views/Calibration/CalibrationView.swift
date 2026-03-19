import SwiftUI
import ARKit
import AVFoundation

/// Calibration view redesigned with a cyberpunk/sci-fi aesthetic.
/// Features a holographic scanner interface, neon styling, and deep space background.
struct CalibrationView: View {
    @StateObject private var calibrationManager = CalibrationManager()
    @Binding var showCalibration: Bool
    @Binding var showTutorial: Bool
    @Binding var showOnboarding: Bool
    @Binding var showHangar: Bool
    
    // MARK: - Local State
    @State private var selectedLighting: LightingCondition = .normal
    @State private var positioningScore: Double = 0.8
    @State private var showingPermissionAlert = false
    @State private var orbitsRotating = false
    @State private var pulseOpacity = false
    @State private var scanLineY: CGFloat = -100
    
    // MARK: - Debug State
    @State private var isDebugEnabled = false
    @State private var debugData = FaceTrackingDebugData()
    
    // MARK: - Constants
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0) // #00F0FF
    private let electricBlue = Color(red: 0.0, green: 0.4, blue: 1.0)
    private let warningOrange = Color(red: 1.0, green: 0.6, blue: 0.0)
    private let deepSpaceBlack = Color(red: 0.05, green: 0.05, blue: 0.1)
    
    var body: some View {
        ZStack {
            // 1. Background Layer (Reused aesthetic from Hangar)
            CalibrationBackground(animate: $orbitsRotating)
                .ignoresSafeArea()
            
            // 2. Main Content
            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.top, 20)
                
                Spacer()
                
                // Central Scanner Area
                ZStack {
                    // AR Camera Feed (Clipped to Circle)
                    if calibrationManager.isDeviceCompatible() {
                        ARViewContainer(
                            session: calibrationManager.arSession,
                            isDebugEnabled: $isDebugEnabled,
                            debugData: $debugData
                        )
                            .frame(width: 240, height: 240)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(neonCyan.opacity(0.3), lineWidth: 1))
                            .opacity(calibrationManager.calibrationState.isCalibrating ? 1.0 : 0.3)
                    }
                    
                    // Holographic Overlays
                    if !isDebugEnabled {
                        switch calibrationManager.calibrationState {
                        case .notStarted:
                            OrbitingCameraScanner(isRotating: $orbitsRotating)
                        case .collectingBaseline:
                            ScanningProgressView(progress: calibrationManager.currentProgress)
                        case .readyForReview:
                            ReviewHologramView()
                        case .completed(_):
                            ReviewHologramView() // Reusing review holo for completed state visuals
                        case .failed:
                            ErrorHologramView()
                        }
                    } else {
                        // Debug Overlay Ring
                        Circle()
                            .stroke(Color.green, lineWidth: 2)
                            .frame(width: 240, height: 240)
                    }
                }
                .frame(maxHeight: 350)
                .padding(.vertical, 20)
                
                // Dynamic Content / Instructions
                VStack(spacing: 20) {
                    if isDebugEnabled {
                        debugHUDView
                    } else {
                        if case .notStarted = calibrationManager.calibrationState {
                            instructionsView
                            lightingSelector
                        } else if case .completed(let calibration) = calibrationManager.calibrationState {
                            completedStatsView(calibration: calibration)
                        } else if case .failed = calibrationManager.calibrationState {
                             errorMessageView
                        } else if case .collectingBaseline = calibrationManager.calibrationState {
                             collectingGuidelinesView
                        }
                    }
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                // Footer Controls
                VStack(spacing: 16) {
                    // Debug Toggle
                    Toggle(isOn: $isDebugEnabled) {
                        Text("DEBUG MODE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(isDebugEnabled ? .green : .gray)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .frame(width: 150)
                    .padding(.bottom, 10)
                    
                    actionButtons
                }
                .padding(.bottom, 30)
                .padding(.horizontal, 40)
            }
        }
        .onAppear {
            orbitsRotating = true
            pulseOpacity = true
            checkCameraPermission()
        }
        .onDisappear {
            calibrationManager.pauseSession()
            UIApplication.shared.isIdleTimerDisabled = false // Restore idle timer
        }
        .alert("Camera Access Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("BlinkBreak needs camera access for the holographic eye scanner.")
        }
        .onChange(of: isDebugEnabled) { enabled in
            calibrationManager.isDebugMode = enabled // Sync with manager
            UIApplication.shared.isIdleTimerDisabled = enabled // Prevent sleep in debug mode
            
            if enabled {
                // Prevent duplicate session start if already running
                if case .collectingBaseline = calibrationManager.calibrationState { return }
                checkCameraPermissionAndStart()
            }
        }
    }
    
    // MARK: - Subviews Hud
    
    private var debugHUDView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("REAL-TIME METRICS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.green)
                .padding(.bottom, 5)
            
            Group {
                debugRow(label: "LOOK UP", value: debugData.lookUp)
                debugRow(label: "LOOK DOWN", value: debugData.lookDown)
                debugRow(label: "LOOK LEFT", value: debugData.lookLeft)
                debugRow(label: "LOOK RIGHT", value: debugData.lookRight)
                Divider().background(Color.green.opacity(0.3))
                debugRow(label: "BLINK LEFT", value: debugData.blinkLeft)
                debugRow(label: "BLINK RIGHT", value: debugData.blinkRight)
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.green.opacity(0.5), lineWidth: 1)
        )
    }
    
    private func debugRow(label: String, value: Float) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 80, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geo.size.width * CGFloat(value), height: 4)
                }
            }
            .frame(height: 4)
            
            Text(String(format: "%.2f", value))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.green)
                .frame(width: 40, alignment: .trailing)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("SYSTEM CALIBRATION")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(neonCyan)
                .shadow(color: neonCyan.opacity(0.8), radius: 10, x: 0, y: 0)
            
            Text(calibrationManager.isFaceDetected ? "SUBJECT DETECTED" : "SEARCHING FOR PILOT...")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .tracking(1)
                .foregroundColor(calibrationManager.isFaceDetected ? Color.green : Color.white.opacity(0.7))
                .animation(.easeInOut, value: calibrationManager.isFaceDetected)
        }
    }
    
    private var instructionsView: some View {
        HStack(spacing: 15) {
            CyberpunkIcon(systemName: "face.smiling", label: "FACE")
            CyberpunkIcon(systemName: "light.max", label: "LIGHT")
            CyberpunkIcon(systemName: "eye", label: "EYES")
        }
        .padding(.vertical, 10)
    }
    
    private var collectingGuidelinesView: some View {
         Text("HOLD STEADY - ACQUIRING BIOMETRICS")
             .font(.system(size: 14, weight: .bold, design: .monospaced))
             .foregroundColor(neonCyan.opacity(0.8))
             .padding()
             .background(neonCyan.opacity(0.1))
             .cornerRadius(8)
             .overlay(RoundedRectangle(cornerRadius: 8).stroke(neonCyan.opacity(0.3), lineWidth: 1))
    }
    
    private var lightingSelector: some View {
        VStack(spacing: 8) {
            Text("ENVIRONMENT LIGHTING")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 0) {
                ForEach(LightingCondition.allCases, id: \.self) { condition in
                    Button(action: {
                        withAnimation { selectedLighting = condition }
                    }) {
                        Text(condition.displayName.uppercased())
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(selectedLighting == condition ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedLighting == condition ? neonCyan : Color.black.opacity(0.3))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(neonCyan.opacity(0.5), lineWidth: 1))
        }
    }
    
    private var errorMessageView: some View {
        Text(calibrationManager.errorMessage ?? "SCANNER ERROR")
            .font(.system(size: 14, design: .monospaced))
            .foregroundColor(warningOrange)
            .padding()
            .background(warningOrange.opacity(0.1))
            .cornerRadius(8)
    }
    
    private func completedStatsView(calibration: CalibrationData) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("SCAN QUALITY")
                    .foregroundColor(.gray)
                Spacer()
                Text("\(Int(calibration.positioningScore * 100))%")
                    .foregroundColor(neonCyan)
            }
            .font(.system(size: 14, design: .monospaced))
            
            HStack {
                Text("EYE OPENNESS")
                    .foregroundColor(.gray)
                Spacer()
                Text(String(format: "%.2f", calibration.averageEyeOpenness))
                    .foregroundColor(neonCyan)
            }
            .font(.system(size: 14, design: .monospaced))
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private var actionButtons: some View {
        VStack(spacing: 16) {
            // Primary Button
            Button(action: handlePrimaryAction) {
                ZStack {
                    // Glow background
                    Capsule()
                        .fill(primaryButtonGradient)
                        .blur(radius: 10)
                        .opacity(pulseOpacity ? 0.6 : 0.3)
                    
                    // Button Shape
                    Capsule()
                        .fill(primaryButtonGradient)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Text
                    Text(primaryButtonText)
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .tracking(1)
                }
                .frame(height: 60)
                .scaleEffect(pulseOpacity ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseOpacity)
            }
            .disabled(!isPrimaryButtonEnabled)
            .opacity(isPrimaryButtonEnabled ? 1.0 : 0.5)
            
            // Secondary / Back Link
            if case .collectingBaseline = calibrationManager.calibrationState {
                Button("ABORT SCAN") {
                    calibrationManager.cancelCalibration()
                }
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(warningOrange)
            } else {
                Button(action: {
                    // Navigate back to Onboarding (manual override)
                    withAnimation {
                        showCalibration = false
                        showHangar = false
                        showOnboarding = true
                    }
                }) {
                    Text("RETURN TO BASE")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(neonCyan.opacity(0.7))
                        .overlay(
                            Rectangle()
                                .frame(height: 1)
                                .offset(y: 10)
                                .foregroundColor(neonCyan.opacity(0.3))
                        )
                }
            }
        }
    }
    
    // MARK: - Helpers & Logic
    
    private var isPrimaryButtonEnabled: Bool {
        switch calibrationManager.calibrationState {
        case .collectingBaseline: return false
        default: return true
        }
    }
    
    private var primaryButtonGradient: LinearGradient {
        LinearGradient(colors: [neonCyan, electricBlue], startPoint: .leading, endPoint: .trailing)
    }
    
    private var primaryButtonText: String {
        switch calibrationManager.calibrationState {
        case .notStarted: return "INITIATE SCAN"
        case .collectingBaseline: return "SCANNING..."
        case .readyForReview: return "CONFIRM DATA"
        case .completed: return "ENGAGE SYSTEMS"
        case .failed: return "RETRY SCAN"
        }
    }
    
    private func handlePrimaryAction() {
        switch calibrationManager.calibrationState {
        case .notStarted, .failed:
            checkCameraPermissionAndStart()
        case .collectingBaseline:
            break
        case .readyForReview:
            calibrationManager.finishCalibration(lightingCondition: selectedLighting, positioningScore: positioningScore)
        case .completed:
            withAnimation {
                showCalibration = false
                showTutorial = true
            }
        }
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Ready to go
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if !granted {
                        self.showingPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showingPermissionAlert = true
        @unknown default:
            break
        }
    }
    
    private func checkCameraPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            calibrationManager.startCalibration()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.calibrationManager.startCalibration()
                    } else {
                        self.showingPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showingPermissionAlert = true
        @unknown default:
            break
        }
    }
}

// MARK: - Safe Data Models

struct FaceTrackingDebugData {
    var lookUp: Float = 0
    var lookDown: Float = 0
    var lookLeft: Float = 0
    var lookRight: Float = 0
    var blinkLeft: Float = 0
    var blinkRight: Float = 0
}

// MARK: - AR View Container

struct ARViewContainer: UIViewRepresentable {
    let session: ARSession
    @Binding var isDebugEnabled: Bool
    @Binding var debugData: FaceTrackingDebugData
    
    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.session = session
        view.automaticallyUpdatesLighting = true
        view.delegate = context.coordinator
        return view
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.isDebugEnabled = isDebugEnabled
        
        // Ensure connection to session (re-inject if needed)
        if uiView.session != session {
            uiView.session = session
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARViewContainer
        var isDebugEnabled: Bool = false
        
        // Cache geometry to avoid recreation
        private var faceGeometry: ARSCNFaceGeometry?
        private var faceNode: SCNNode?
        
        init(_ parent: ARViewContainer) {
            self.parent = parent
        }
        
        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard let device = renderer.device, isDebugEnabled, anchor is ARFaceAnchor else { return nil }
            
            // Create face geometry
            if faceGeometry == nil {
                faceGeometry = ARSCNFaceGeometry(device: device)
            }
            
            // Create node
            let node = SCNNode(geometry: faceGeometry)
            node.geometry?.firstMaterial?.fillMode = .lines // Wireframe
            node.geometry?.firstMaterial?.diffuse.contents = UIColor.white
            node.geometry?.firstMaterial?.lightingModel = .constant
            
            self.faceNode = node
            return node
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor else { return }
            
            // Update Mesh if visible
            if isDebugEnabled, let faceGeometry = faceGeometry {
                faceGeometry.update(from: faceAnchor.geometry)
                
                // Ensure node is attached if we just enabled debug
                if node.childNodes.isEmpty {
                   // If scene/renderer logic cleared it, we might need to re-add.
                   // ARKit renderer(nodeFor:) is only called once per anchor add.
                   // Toggling debug ON after anchor is added means we need to manually add geometry.
                   // For simplicity in this constraint satisfaction, we assume AR session reset or consistent state.
                   // A robust impl might manually attach/detach geometry node here.
                   if let fNode = faceNode {
                       node.addChildNode(fNode)
                   }
                }
            } else {
                 // Clean up if debug disabled
                 node.enumerateChildNodes { (child, _) in
                     child.removeFromParentNode()
                 }
            }

            // Extract Data
            let blendShapes = faceAnchor.blendShapes
            let lookUp = blendShapes[.eyeLookUpLeft]?.floatValue ?? 0
            let lookDown = blendShapes[.eyeLookDownLeft]?.floatValue ?? 0
            let lookLeft = blendShapes[.eyeLookInLeft]?.floatValue ?? 0
            let lookRight = blendShapes[.eyeLookOutLeft]?.floatValue ?? 0
            let blinkLeft = blendShapes[.eyeBlinkLeft]?.floatValue ?? 0
            let blinkRight = blendShapes[.eyeBlinkRight]?.floatValue ?? 0
            
            let debugState = FaceTrackingDebugData(
                lookUp: lookUp,
                lookDown: lookDown,
                lookLeft: lookLeft,
                lookRight: lookRight,
                blinkLeft: blinkLeft,
                blinkRight: blinkRight
            )
            
            let parent = self.parent
            DispatchQueue.main.async {
                parent.debugData = debugState
            }
        }
    }
}

// MARK: - Custom Visual Components

struct CalibrationBackground: View {
    @Binding var animate: Bool
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1) // Deep space black
            
            // Grid
            GeometryReader { geo in
                Path { path in
                    let step: CGFloat = 50
                    for x in stride(from: 0, to: geo.size.width + step, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    for y in stride(from: 0, to: geo.size.height + step, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(Color.blue.opacity(0.05), lineWidth: 1)
            }
            
            // Floating Particles
            ForEach(0..<15) { _ in
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: CGFloat.random(in: 1...3))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
            }
        }
    }
}

struct OrbitingCameraScanner: View {
    @Binding var isRotating: Bool
    
    var body: some View {
        ZStack {
            // Core Lens
            Circle()
                .fill(
                    RadialGradient(colors: [Color.black.opacity(0.1), Color(red: 0.1, green: 0.1, blue: 0.2).opacity(0.3)], center: .center, startRadius: 0, endRadius: 80)
                )
                .frame(width: 160, height: 160)
                .overlay(Circle().stroke(Color.cyan.opacity(0.5), lineWidth: 2))
                .shadow(color: Color.cyan.opacity(0.5), radius: 30)
            
            // Inner Reflection
            Circle()
                .fill(Color.cyan.opacity(0.05))
                .frame(width: 140, height: 140)
            
            // Rotating Rings
            ForEach(0..<3) { i in
                Circle()
                    .stroke(
                        LinearGradient(colors: [.cyan, .clear, .blue, .clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: 2
                    )
                    .frame(width: 200 + CGFloat(i * 30), height: 200 + CGFloat(i * 30))
                    .rotationEffect(.degrees(isRotating ? 360 : 0))
                    .rotation3DEffect(.degrees(45 + Double(i * 15)), axis: (x: 1, y: 0, z: 0))
                    .animation(Animation.linear(duration: 8 + Double(i)).repeatForever(autoreverses: false), value: isRotating)
            }
            
            // Scan aperture
            Image(systemName: "camera.aperture")
                .resizable()
                .foregroundColor(.cyan)
                .frame(width: 60, height: 60)
                .opacity(0.8)
        }
    }
}

struct ScanningProgressView: View {
    let progress: Double
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Outer Ring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                .frame(width: 200, height: 200)
            
            // Progress Ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.2), value: progress)
            
            // Inner Spinner
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(Color.cyan.opacity(0.5), style: StrokeStyle(lineWidth: 4, dash: [10, 5]))
                .frame(width: 170, height: 170)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
            
            // Percentage
            VStack {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("ACQUIRING")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }
        }
    }
}

struct ReviewHologramView: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.green.opacity(0.5), lineWidth: 4)
                .frame(width: 180, height: 180)
            
            Image(systemName: "checkmark.shield.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.green)
                .shadow(color: .green.opacity(0.8), radius: 20)
            
            Text("DATA VERIFIED")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.green)
                .offset(y: 80)
        }
    }
}

struct ErrorHologramView: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.orange.opacity(0.5), lineWidth: 4)
                .frame(width: 180, height: 180)
            
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.orange)
                .shadow(color: .orange.opacity(0.8), radius: 20)
        }
    }
}

struct CyberpunkIcon: View {
    let systemName: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                .fill(Color.black.opacity(0.5))
                .frame(width: 60, height: 60)
                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                
                Image(systemName: systemName)
                    .font(.system(size: 24))
                    .foregroundColor(.cyan)
                    .shadow(color: .cyan.opacity(0.5), radius: 5)
            }
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    CalibrationView(showCalibration: .constant(true), showTutorial: .constant(false), showOnboarding: .constant(false), showHangar: .constant(false))
}