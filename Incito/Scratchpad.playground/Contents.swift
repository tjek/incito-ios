import UIKit
import PlaygroundSupport

//let label1: UILabel = {
//    let label = UILabel()
//label.numberOfLines = 0
//label.attributedText = {
//
//    let font = UIFont.boldSystemFont(ofSize: 20)
//    let textColor = UIColor.black
//
//    let alignment = NSTextAlignment.center
//
//    let string = "This is long long line of text over multiple lines"
//
//    let paragraphStyle = NSMutableParagraphStyle()
//
//    let lineSpacingMultiplier: CGFloat = 1.4
//
//    paragraphStyle.lineSpacing = 0
//    //        paragraphStyle.lineHeightMultiple = (CGFloat(lineSpacingMultiplier) - 1) / 2 + 1
//
//    //        let lineHeightDiff = font.lineHeight * CGFloat(lineSpacingMultiplier) - font.lineHeight
//    //        paragraphStyle.lineSpacing = lineHeightDiff / 2 // desiredLineHeight - font.lineHeight
//    paragraphStyle.alignment = alignment
//
//    let offset = 4 //(font.lineHeight * (lineSpacingMultiplier - 1)) / (2 + lineSpacingMultiplier) / 2
//
////    let scaledMult = font.lineHeight / (font.lineHeight - offset)
//    let scaledMult = lineSpacingMultiplier //(font.lineHeight * lineSpacingMultiplier) / (2 * offset + font.lineHeight)
//
//    paragraphStyle.lineHeightMultiple = scaledMult
//
//    let attrStr = NSMutableAttributedString(
//        string: string,
//        attributes: [.foregroundColor: textColor,
//                     .backgroundColor: UIColor.blue.withAlphaComponent(0.5),
//                                              .baselineOffset: offset,
//            .font: font,
//            .paragraphStyle: paragraphStyle
//        ]
//    )
//
//    return attrStr
//}()
//    return label
//}()
//
//let label2: UILabel = {
//    let label = UILabel()
//    label.numberOfLines = 0
//    label.attributedText = {
//
//        let font = UIFont.boldSystemFont(ofSize: 20)
//        let textColor = UIColor.red
//
//        let alignment = NSTextAlignment.center
//
//        let string = "This is long long line of text over multiple lines"
//
//        let paragraphStyle = NSMutableParagraphStyle()
//
//        let lineSpacingMultiplier: CGFloat = 1.4
//
//        paragraphStyle.lineSpacing = 0
//        //        paragraphStyle.lineHeightMultiple = (CGFloat(lineSpacingMultiplier) - 1) / 2 + 1
//
//        //        let lineHeightDiff = font.lineHeight * CGFloat(lineSpacingMultiplier) - font.lineHeight
//        //        paragraphStyle.lineSpacing = lineHeightDiff / 2 // desiredLineHeight - font.lineHeight
//        paragraphStyle.alignment = alignment
//
//        let offset = 0 //(font.lineHeight * (lineSpacingMultiplier - 1)) / (2 + lineSpacingMultiplier)
//
//        let scaledMult = lineSpacingMultiplier //font.lineHeight / (font.lineHeight - offset)
//
//        paragraphStyle.lineHeightMultiple = scaledMult
//
//        let attrStr = NSMutableAttributedString(
//            string: string,
//            attributes: [.foregroundColor: textColor,
//                         .backgroundColor: UIColor.blue.withAlphaComponent(0.5),
//                         .baselineOffset: offset,
//                         .font: font,
//                         .paragraphStyle: paragraphStyle
//            ]
//        )
//
//        return attrStr
//    }()
//    return label
//}()
////let boundingBox = label.attributedText!.boundingRect(
////    with: label.frame.size,
////    options: [.usesLineFragmentOrigin],
////    context: nil)
////
////print("Size:", boundingBox.size.height)
//// (lineHMult * lineHeight * lineCount) + (lineSpacing * (lineCount-1)) + (baselineOffset * lineCount * lineHMult)
//
//let view = UIView()
//
//view.backgroundColor = .white
//view.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
//
//view.addSubview(label1)
//label1.frame = view.bounds
//
//view.addSubview(label2)
//label2.alpha = 0.5
//label2.frame = view.bounds
//
//PlaygroundPage.current.liveView = view
////81.6015625
//// 73.6015625
//// 40.1875 34.8
