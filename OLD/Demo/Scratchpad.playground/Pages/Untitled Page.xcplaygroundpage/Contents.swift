import UIKit
import PlaygroundSupport

enum FontLoadingError: Error {
    case invalidData // unable to convert data into a CGFont
    case registrationFailed
    case postscriptNameUnavailable
}
extension UIFont {
    /// Returns the name of the registered font, or nil if there is a problem.
    static func register(data: Data) throws -> String {
        
        guard let dataProvider = CGDataProvider(data: data as CFData),
            let cgFont = CGFont(dataProvider) else {
                throw(FontLoadingError.invalidData)
        }
        
        guard let fontName = cgFont.postScriptName else {
            throw(FontLoadingError.postscriptNameUnavailable)
        }
        
        // try to register the font. if it fails _but_ the font is still available (eg. it was already registered), then success!
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterGraphicsFont(cgFont, &error) == false,
            UIFont(name: String(fontName), size: 0) == nil {
            
            throw(FontLoadingError.registrationFailed)
        }
        
        return String(fontName)
    }
}




////////////////

func buildFont(name: String, size: CGFloat) -> UIFont {
    guard let fontURL = Bundle.main.url(forResource: name, withExtension: nil),
        let fontData = try? Data(contentsOf: fontURL),
        let fontName = try? UIFont.register(data: fontData) else {
            fatalError()
    }
    
    return UIFont(name: fontName, size: size)!
}

func buildAttrStr(
    string: String,
    font: UIFont,
    lineSpacingMultiplier: CGFloat,
    textColor: UIColor) -> NSAttributedString {

    let alignment = NSTextAlignment.center
    
    /*
     lineHeightMult: 1.4
     lineHeight: 21.600000381469727
     xHeight: 10.800000190734863
     descender: -3.780000066757202
     asc: 17.820000314712523
     cap: 14.904
     maxLineHeight: 30.240000534057614
     
     baselineOffset = ~2.5 <- (4.5 / 1.4)
     lineSpacing = -0.3
     
     
     lineHeightMult: 1.8
     lineHeight: 26.0 (46.8)
     xHeight: 13.0 (23.4)
     descender: -4.55 (8.19)
     asc: 21.45 (38.61)
     cap: 17.94
     maxLineHeight: 46.800000000000004
     
     baselineOffset = ~6.3 <- (11.5 / 1.8)
     
     lineSpacing = -1.0
     
     
     //////
     
     fontSize: 35.0
     lineHeightMult: 2.0
     
     lineSpacing: -0.2
     
     lineHeight: 35.00000000000001 xHeight: 17.5 descender: -6.125000000000001 asc: 28.875000000000004 capHeight: 24.150000000000002
     baselineOffset: 8.75
     maxLineHeight: 70.00000000000001
     
     */
    
    let maxLineHeight = floor(font.pointSize * lineSpacingMultiplier)
//    let baselineOffset: CGFloat = (maxLineHeight - (maxLineHeight / 2 + lineHeight / 2)) / lineSpacingMultiplier
//    let baselineOffsetB: CGFloat = ((font.lineHeight * lineSpacingMultiplier - font.lineHeight) / 4)
    
    let baselineOffset = 0 //((maxLineHeight / 2) - (font.lineHeight / 2)) / 2
//    let baselineOffsetB: CGFloat = (lineHeight * lineSpacingMultiplier - lineHeight) / (2 * lineSpacingMultiplier)
//    let baselineOffset: CGFloat = font.descender
//        (maxLineHeight - (maxLineHeight / 2 + lineHeight / 2)) / lineSpacingMultiplier
    
    let lineHeightMult: CGFloat = lineSpacingMultiplier
    let lineSpacing: CGFloat = 0
    
    print("""
        ----
        fontSize: \(font.pointSize)
        lineHeight: \(font.lineHeight) xHeight: \(font.xHeight) descender: \(font.descender) asc: \(font.ascender) capHeight: \(font.capHeight)
        baselineOffset: \(baselineOffset)
        lineHeightMult: \(lineHeightMult)
        lineSpacing: \(lineSpacing)
        maxLineHeight: \(maxLineHeight)
        """)
    
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineHeightMultiple = lineHeightMult
    paragraphStyle.lineSpacing = 0
    paragraphStyle.alignment = alignment
//    paragraphStyle.maximumLineHeight = maxLineHeight
//    paragraphStyle.minimumLineHeight = maxLineHeight

    let attrStr = NSMutableAttributedString(
        string: string,
        attributes: [.foregroundColor: textColor,
                     .font: font,
                     .baselineOffset: baselineOffset,
                     .paragraphStyle: paragraphStyle
        ]
    )
    
    return attrStr
}

func buildLabelView(attrStr: NSAttributedString, refImgName: String, bgColor: UIColor, numberOfLines: Int = 0) -> UIView {
    
    let view = UIView()
    
    view.backgroundColor = bgColor

    let refView = UIImageView(image: UIImage(named: refImgName))
    refView.alpha = 0.5
    view.addSubview(refView)
    var refFrm = refView.frame
    refFrm.size = CGSize(width: refFrm.size.width, height: refFrm.size.height)
    refView.frame = refFrm

    view.frame = refFrm
    
    let label = UILabel()
    label.backgroundColor = UIColor.red.withAlphaComponent(0.2)
    label.attributedText = attrStr
    label.numberOfLines = numberOfLines
    
    view.addSubview(label)
    var lblFrm = view.bounds.inset(by: UIEdgeInsets(top: 30, left: 30, bottom: 30, right: 30))
    let textHeight = label.sizeThatFits(CGSize(width: lblFrm.size.width, height: 0)).height
    
    lblFrm.size.height = textHeight
    label.frame = lblFrm

    let calcdSize = attrStr.boundingRect(with: lblFrm.size, options: [.usesLineFragmentOrigin], context: nil).size
    print(ceil(calcdSize.height), lblFrm.size.height, view.bounds.inset(by: UIEdgeInsets(top: 30, left: 30, bottom: 30, right: 30)).size.height)
    
    
    
    return view
}


let faktaFontName = "fakta_bold-webfont.ttf"
let istokFontName = "istok-web-v11-latin-regular.ttf"

let string = "Tilbuddene gælder fra torsdag den 22. november til onsdag den 28. november 2018"
//let string = "Tilbuddene gælder fra torsdag den"

let viewA = buildLabelView(
    attrStr: buildAttrStr(
        string: string,
        font: buildFont(name: faktaFontName, size: 21.599999999999998),
        lineSpacingMultiplier: 1.4,
        textColor: .purple
    ),
    refImgName: "titleText_ref_image.jpg",
    bgColor: .white
)

let viewB = buildLabelView(
    attrStr: buildAttrStr(
        string: string,
        font: buildFont(name: "fakta_bold-webfont.woff", size: 26),
        lineSpacingMultiplier: 1.8,
        textColor: .purple
    ),
    refImgName: "titleText_ref_imageB.jpg",
    bgColor: .white
)

var frmB = viewB.frame
frmB.origin.y = viewA.frame.maxY + 10
viewB.frame = frmB

//let viewC = buildLabelView(
//    attrStr: buildAttrStr(
//        string: string,
//        font: buildFont(name: faktaFontName, size: 20),
//        lineSpacingMultiplier: 2.5,
//        textColor: .purple
//    ),
//    refImgName: "titleText_ref_imageD.jpg",
//    bgColor: .white
//)
let viewC = buildLabelView(
    attrStr: buildAttrStr(
        string: "Under halv",
        font: buildFont(name: istokFontName, size: 20),
        lineSpacingMultiplier: 1.1,
        textColor: .purple
    ),
    refImgName: "underhalv.jpg",
    bgColor: .white,
    numberOfLines: 1
)

viewC.layer.anchorPoint = .zero
viewC.transform = viewC.transform.scaledBy(x: 2, y: 2)


var frmC = viewC.frame
frmC.origin.y = viewB.frame.maxY + 10
viewC.frame = frmC

let viewD = buildLabelView(
    attrStr: buildAttrStr(
        string: "Tilbuddene gælder fra torsdag den 22. novem-ber til onsdag den 28. november 2018",
        font: buildFont(name: faktaFontName, size: 35),
        lineSpacingMultiplier: 2,
        textColor: .purple
    ),
    refImgName: "titleText_ref_imageC.jpg",
    bgColor: .white
)

var frmD = viewD.frame
frmD.origin.y = viewC.frame.maxY + 10
viewD.frame = frmD

let container = UIView()
container.backgroundColor = .white

container.addSubview(viewA)
container.addSubview(viewB)
container.addSubview(viewC)
container.addSubview(viewD)

//let container = UIStackView(arrangedSubviews: [viewA, viewB])
////viewA.translatesAutoresizingMaskIntoConstraints = false
////viewB.translatesAutoresizingMaskIntoConstraints = false
//container.axis = .vertical
container.frame = CGRect(
    origin: .zero,
    size: CGSize(
        width: viewA.frame.size.width,
        height: viewD.frame.maxY
    )
)
//container.updateConstraints()
//viewA.setNeedsLayout()
//viewB.setNeedsLayout()
//container.layoutIfNeeded()
//dump(container)
let c = UIView()
c.backgroundColor = UIColor(white: 0.9, alpha: 1)

func attributedString(
    string: String,
    font: UIFont,
    lineHeightMultiplier: CGFloat,
    textColor: UIColor
    ) -> NSAttributedString {
    
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineHeightMultiple = lineHeightMultiplier
    
    let attrStr = NSMutableAttributedString(
        string: string,
        attributes: [.font: font,
                      .foregroundColor: textColor,
                     .paragraphStyle: paragraphStyle
        ]
    )
    
    return attrStr
}

func exampleLbl(m lineSpacingMultiplier: CGFloat, yOffset: CGFloat) -> UILabel {
    let lbl = UILabel()

    lbl.numberOfLines = 0
    
    lbl.attributedText = attributedString(
        string: "The vorpal blade went snicker-snack!",
        font: buildFont(name: faktaFontName, size: 35),
        lineHeightMultiplier: lineSpacingMultiplier,
        textColor: .white)
//    lbl.attributedText = buildAttrStr(
//        string: "The vorpal blade went snicker-snack!",
//        font: buildFont(name: faktaFontName, size: 35),
//        lineSpacingMultiplier: lineSpacingMultiplier,
//        textColor: .white
//    )
    lbl.textAlignment = .center
    lbl.backgroundColor = UIColor.orange
    let size = lbl.sizeThatFits(CGSize(width: 400, height: 0))
    lbl.frame = CGRect(x: 10, y: yOffset, width: 400, height: size.height)
    return lbl
}

let lbl1 = exampleLbl(m: 1, yOffset: 10)
let lbl2 = exampleLbl(m: 1.5, yOffset: lbl1.frame.maxY + 10)
let lbl3 = exampleLbl(m: 2, yOffset: lbl2.frame.maxY + 10)
c.addSubview(lbl1)
c.addSubview(lbl2)
c.addSubview(lbl3)

c.frame = CGRect(origin: .zero, size: CGSize(width: lbl3.frame.maxX + 10, height: lbl3.frame.maxY + 10))


PlaygroundPage.current.liveView = c
//81.6015625
// 73.6015625
// 40.1875 34.8
