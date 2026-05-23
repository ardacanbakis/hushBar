import SwiftUI

/// Hand-built vector brand marks (no external assets, since the build
/// environment can't fetch logo files). YouTube/Spotify/Instagram/LinkedIn are
/// close to the real marks; GitHub is a stylized Octocat-style cat.
enum Brand {
    case website, github, instagram, youtube, spotify, linkedin
}

struct BrandIcon: View {
    let brand: Brand
    var size: CGFloat = 22

    var body: some View {
        Group {
            switch brand {
            case .website: WebsiteIcon(size: size)
            case .github: GitHubIcon(size: size)
            case .instagram: InstagramIcon(size: size)
            case .youtube: YouTubeIcon(size: size)
            case .spotify: SpotifyIcon(size: size)
            case .linkedin: LinkedInIcon(size: size)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Shapes

private struct PlayTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct SpotifyArcs: Shape {
    func path(in rect: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var p = Path()
        p.move(to: pt(0.20, 0.45)); p.addQuadCurve(to: pt(0.80, 0.45), control: pt(0.50, 0.30))
        p.move(to: pt(0.26, 0.59)); p.addQuadCurve(to: pt(0.75, 0.59), control: pt(0.50, 0.46))
        p.move(to: pt(0.32, 0.72)); p.addQuadCurve(to: pt(0.69, 0.72), control: pt(0.50, 0.61))
        return p
    }
}

private struct CatMark: Shape {
    func path(in rect: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var p = Path()
        // Head
        p.addEllipse(in: CGRect(x: rect.minX + 0.14 * rect.width,
                                y: rect.minY + 0.30 * rect.height,
                                width: 0.72 * rect.width,
                                height: 0.62 * rect.height))
        // Left ear
        p.move(to: pt(0.20, 0.40)); p.addLine(to: pt(0.28, 0.08)); p.addLine(to: pt(0.46, 0.30)); p.closeSubpath()
        // Right ear
        p.move(to: pt(0.80, 0.40)); p.addLine(to: pt(0.72, 0.08)); p.addLine(to: pt(0.54, 0.30)); p.closeSubpath()
        return p
    }
}

// MARK: - Icons

private struct WebsiteIcon: View {
    let size: CGFloat
    var body: some View {
        Image(systemName: "globe")
            .resizable().scaledToFit()
            .foregroundColor(Color(red: 0.18, green: 0.52, blue: 0.90))
    }
}

private struct GitHubIcon: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            CatMark().fill(Color.primary)
            // Eyes
            HStack(spacing: size * 0.16) {
                Circle().fill(Color(NSColor.windowBackgroundColor)).frame(width: size * 0.08, height: size * 0.08)
                Circle().fill(Color(NSColor.windowBackgroundColor)).frame(width: size * 0.08, height: size * 0.08)
            }
            .offset(y: size * 0.04)
        }
    }
}

private struct InstagramIcon: View {
    let size: CGFloat
    private var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.40, green: 0.31, blue: 0.85),
                Color(red: 0.83, green: 0.18, blue: 0.42),
                Color(red: 0.99, green: 0.62, blue: 0.26),
            ],
            startPoint: .bottomLeading, endPoint: .topTrailing)
    }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .stroke(gradient, lineWidth: size * 0.11)
                .frame(width: size * 0.82, height: size * 0.82)
            Circle()
                .stroke(gradient, lineWidth: size * 0.11)
                .frame(width: size * 0.40, height: size * 0.40)
            Circle()
                .fill(gradient)
                .frame(width: size * 0.10, height: size * 0.10)
                .offset(x: size * 0.20, y: -size * 0.20)
        }
    }
}

private struct YouTubeIcon: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(Color(red: 1.0, green: 0.0, blue: 0.0))
                .frame(width: size, height: size * 0.70)
            PlayTriangle()
                .fill(.white)
                .frame(width: size * 0.22, height: size * 0.26)
                .offset(x: size * 0.02)
        }
    }
}

private struct SpotifyIcon: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(Color(red: 0.114, green: 0.725, blue: 0.329))
            SpotifyArcs()
                .stroke(.white, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
        }
    }
}

private struct LinkedInIcon: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.20, style: .continuous)
                .fill(Color(red: 0.039, green: 0.40, blue: 0.76))
            Text("in")
                .font(.system(size: size * 0.56, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .offset(y: -size * 0.01)
        }
    }
}
