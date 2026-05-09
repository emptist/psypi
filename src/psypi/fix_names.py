import re
with open('extension_generator.gleam', 'r') as f:
    content = f.read()

# Replace type names first
content = content.replace('IdentityNeed', 'PiIdentityNeed')
content = content.replace('ResultKind', 'PiResultKind')

# Replace variant constructors (must be precise to avoid double Pi)
# Order matters: longer names first to avoid partial replacements
content = content.replace('PartnerIdentity', 'PiPartnerIdentity')
content = content.replace('BothIdentities', 'PiBothIdentities')
content = content.replace('MyIdentity', 'PiMyIdentity')
content = content.replace('SimpleText(', 'PiSimpleText(')
content = content.replace('Stats', 'PiStats')
content = content.replace('RawJson', 'PiRawJson')
content = content.replace('None', 'PiNone')

# Fix double Pi prefixes that may have formed
content = content.replace('PiPiNone', 'PiNone')
content = content.replace('PiPiMyIdentity', 'PiMyIdentity')
content = content.replace('PiPiPartnerIdentity', 'PiPartnerIdentity')
content = content.replace('PiPiBothIdentities', 'PiBothIdentities')
content = content.replace('PiPiRawJson', 'PiRawJson')
content = content.replace('PiPiSimpleText', 'PiSimpleText')
content = content.replace('PiPiStats', 'PiStats')

with open('extension_generator.gleam', 'w') as f:
    f.write(content)
print('Done')
