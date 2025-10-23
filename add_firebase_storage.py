#!/usr/bin/env python3
"""
Add FirebaseStorage to MessageAI Xcode project
This script modifies the project.pbxproj file to add FirebaseStorage dependency
"""

import re

# Read the project file
with open('/Users/momenmush/Downloads/MessageAI/MessageAI.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# 1. Add FirebaseStorage to packageProductDependencies array
# Find the section and add FirebaseStorage
pattern = r'(packageProductDependencies = \(\s+A5FB00012EA8300000000001 /\* FirebaseAuth \*/,\s+A5FB00022EA8300000000002 /\* FirebaseFirestore \*/,\s+A5FB00042EA8300000000004 /\* FirebaseMessaging \*/,\s+A5FB00052EA8300000000005 /\* FirebaseAnalytics \*/,)'

replacement = r'''\1
\t\t\t\tA5FB00062EA8300000000006 /* FirebaseStorage */,'''

content = re.sub(pattern, replacement, content)

# 2. Add FirebaseStorage product dependency definition
# Find the XCSwiftPackageProductDependency section and add FirebaseStorage
pattern = r'(A5FB00052EA8300000000005 /\* FirebaseAnalytics \*/ = \{\s+isa = XCSwiftPackageProductDependency;\s+package = A5FB00002EA8300000000000 /\* XCRemoteSwiftPackageReference "firebase-ios-sdk" \*/;\s+productName = FirebaseAnalytics;\s+\};)'

replacement = r'''\1
\t\tA5FB00062EA8300000000006 /* FirebaseStorage */ = {
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tpackage = A5FB00002EA8300000000000 /* XCRemoteSwiftPackageReference "firebase-ios-sdk" */;
\t\t\tproductName = FirebaseStorage;
\t\t};'''

content = re.sub(pattern, replacement, content)

# 3. Add FirebaseStorage to PBXBuildFile section (for Frameworks)
# First find the pattern for existing Firebase build files
pattern = r'(A52EBF622EA85C3D008D65D8 /\* FirebaseAnalytics in Frameworks \*/ = \{isa = PBXBuildFile; productRef = A5FB00052EA8300000000005 /\* FirebaseAnalytics \*/; \};)'

replacement = r'''\1
\t\tA52EBF632EA85C3D008D65D8 /* FirebaseStorage in Frameworks */ = {isa = PBXBuildFile; productRef = A5FB00062EA8300000000006 /* FirebaseStorage */; };'''

content = re.sub(pattern, replacement, content)

# 4. Add FirebaseStorage to Frameworks phase
pattern = r'(A52EBF622EA85C3D008D65D8 /\* FirebaseAnalytics in Frameworks \*/,)'

replacement = r'''\1
\t\t\t\tA52EBF632EA85C3D008D65D8 /* FirebaseStorage in Frameworks */,'''

content = re.sub(pattern, replacement, content)

# Write the modified content back
with open('/Users/momenmush/Downloads/MessageAI/MessageAI.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("✅ Successfully added FirebaseStorage to project.pbxproj")
print("🔄 Now run: xcodebuild -scheme MessageAI -sdk iphonesimulator build")
