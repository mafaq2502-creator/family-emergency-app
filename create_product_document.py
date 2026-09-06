from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

OUT = r"C:\Users\Farhan\Documents\family_emergency_app\Family_Emergency_App_Product_Plan.docx"

doc = Document()
section = doc.sections[0]
section.top_margin = Inches(0.7)
section.bottom_margin = Inches(0.7)
section.left_margin = Inches(0.75)
section.right_margin = Inches(0.75)

styles = doc.styles
styles['Normal'].font.name = 'Aptos'
styles['Normal']._element.rPr.rFonts.set(qn('w:ascii'), 'Aptos')
styles['Normal']._element.rPr.rFonts.set(qn('w:hAnsi'), 'Aptos')
styles['Normal'].font.size = Pt(10.5)
for style_name, size in [('Title', 24), ('Heading 1', 16), ('Heading 2', 12)]:
    style = styles[style_name]
    style.font.name = 'Aptos Display'
    style._element.rPr.rFonts.set(qn('w:ascii'), 'Aptos Display')
    style._element.rPr.rFonts.set(qn('w:hAnsi'), 'Aptos Display')
    style.font.size = Pt(size)
    style.font.color.rgb = RGBColor(0, 0, 0)

def set_cell_shading(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:fill'), fill)
    tc_pr.append(shd)

def set_cell_border(cell, color='D9D9D9'):
    tc_pr = cell._tc.get_or_add_tcPr()
    borders = OxmlElement('w:tcBorders')
    for edge in ('top', 'left', 'bottom', 'right'):
        tag = OxmlElement(f'w:{edge}')
        tag.set(qn('w:val'), 'single')
        tag.set(qn('w:sz'), '4')
        tag.set(qn('w:color'), color)
        borders.append(tag)
    tc_pr.append(borders)

def set_cell_text(cell, text, bold=False, color=None, size=9.5):
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(0)
    run = p.add_run(text)
    run.bold = bold
    run.font.size = Pt(size)
    if color:
        run.font.color.rgb = RGBColor(*color)
    cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
    set_cell_border(cell)

def heading(text, level=1):
    p = doc.add_paragraph(style=f'Heading {level}')
    p.paragraph_format.space_before = Pt(16 if level == 1 else 10)
    p.paragraph_format.space_after = Pt(6)
    p.add_run(text)
    return p

def para(text='', bold_lead=None):
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(6)
    if bold_lead and text.startswith(bold_lead):
        p.add_run(bold_lead).bold = True
        p.add_run(text[len(bold_lead):])
    else:
        p.add_run(text)
    return p

def bullet(text, level=0):
    p = doc.add_paragraph(style='List Bullet' if level == 0 else 'List Bullet 2')
    p.paragraph_format.space_after = Pt(3)
    p.add_run(text)
    return p

def add_table(headers, rows, widths=None):
    table = doc.add_table(rows=1, cols=len(headers))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.style = 'Table Grid'
    header_cells = table.rows[0].cells
    for i, value in enumerate(headers):
        set_cell_shading(header_cells[i], '263238')
        set_cell_text(header_cells[i], value, bold=True, color=(255, 255, 255))
        if widths:
            header_cells[i].width = Inches(widths[i])
    for row_index, row in enumerate(rows):
        cells = table.add_row().cells
        for i, value in enumerate(row):
            if row_index % 2 == 1:
                set_cell_shading(cells[i], 'F5F7F8')
            set_cell_text(cells[i], value)
            if widths:
                cells[i].width = Inches(widths[i])
    doc.add_paragraph().paragraph_format.space_after = Pt(1)
    return table

def flow_step(text, accent=False):
    table = doc.add_table(rows=1, cols=1)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    cell = table.cell(0, 0)
    set_cell_shading(cell, 'FCE4E4' if accent else 'F3F5F6')
    p = cell.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(0)
    run = p.add_run(text)
    run.bold = True
    run.font.size = Pt(10)
    set_cell_border(cell, 'C8CED1')
    arrow = doc.add_paragraph()
    arrow.alignment = WD_ALIGN_PARAGRAPH.CENTER
    arrow.paragraph_format.space_before = Pt(0)
    arrow.paragraph_format.space_after = Pt(0)
    arrow.add_run('↓').font.size = Pt(15)

title = doc.add_paragraph(style='Title')
title.alignment = WD_ALIGN_PARAGRAPH.CENTER
title.add_run('Family Emergency App Product Plan')
subtitle = doc.add_paragraph()
subtitle.alignment = WD_ALIGN_PARAGRAPH.CENTER
subtitle.paragraph_format.space_after = Pt(16)
subtitle.add_run('Product requirements, plan model, user flows, and implementation roadmap').italic = True

heading('Purpose', 1)
para('This document brings together the current Flutter project, the agreed UI direction, the Free and Premium plan rules, and the proposed safety flows. The key decision is that subscriptions belong to a Family Circle owner, while every member keeps control over the data they share.')

heading('Current Project Status', 1)
add_table(
    ['Area', 'Current state', 'Next work'],
    [
        ['Flutter app', 'Firebase Auth, Firestore sign-up, login, home, family, location placeholder, and profile screens exist.', 'Refresh the visual design and improve the data model.'],
        ['Profile', 'The screen can load Firestore data and supports editable name and relation.', 'Fix missing profile data for existing accounts and add profile photo upload.'],
        ['Home', 'Mock location, battery, family status, and an SOS countdown are present.', 'Replace mock information with approved real data and new UI.'],
        ['Plans', 'Not implemented.', 'Create Family Circle subscription, seats, and feature access rules.'],
        ['Alerts', 'Not implemented.', 'Build Daily Check-in first, then Premium device monitoring.'],
    ],
    [1.25, 3.0, 2.5],
)

heading('Product Structure', 1)
para('The product is organized around a Family Circle. One user creates or owns a circle, invites family members, and manages the plan. Every invited person has their own account and gives their own permissions. A paid owner does not make another person personally paid; instead, that person receives the circle features for the circle they joined.')

add_table(
    ['Role', 'What they control', 'What they receive'],
    [
        ['Family Circle owner', 'Plan, billing, member slots, invitations, and alert settings.', 'All plan features for their Family Circle.'],
        ['Family member', 'Own profile, profile photo, location, battery, notification, and check-in consent.', 'Features enabled by that Family Circle after consent.'],
        ['Platform', 'Secure identity, permissions, alert scheduling, and subscription enforcement.', 'Does not expose private data without authorization.'],
    ],
    [1.35, 3.15, 2.25],
)

heading('Plan and Seat Model', 1)
para('Recommendation: charge per Family Circle, not per individual login. The owner pays once for the circle. Members can remain Free users on their own account, but participate in the owner\'s Premium circle after they accept the invitation and approve the required permissions.')
add_table(
    ['Plan', 'Included active members', 'Features', 'Billing'],
    [
        ['Free', 'Owner plus 2 invited members', 'Manual SOS, family management, emergency contacts, Daily Check-in, optional missed-check-in alerts.', 'No charge. Third member requires upgrade.'],
        ['Premium', 'Owner plus 10 invited members', 'Everything in Free plus approved live location, battery status, 5 percent battery alerts, offline alerts, SMS fallback, and alert history.', 'One family subscription.'],
        ['Extra seats', 'Each active member above 10', 'Same Premium feature access inside the owner\'s circle after consent.', 'Extra monthly charge per active member.'],
    ],
    [1.05, 1.45, 3.0, 1.25],
)
para('An active member is someone with an accepted invitation in the circle. Removed, declined, or expired invitations do not consume a paid seat. The app should show the owner a clear count, for example: “8 of 10 Premium member slots used.”')

heading('Subscription and Invitation Flow', 1)
flow_step('User creates a Family Circle')
flow_step('User selects Free or Premium plan')
flow_step('Owner invites family member by email or phone')
flow_step('Member accepts invitation with their own account')
flow_step('System checks available member slots')
flow_step('Member chooses data permissions', accent=True)
flow_step('Member joins circle and receives allowed circle features')
para('If a Free owner attempts to add a third invited member, show the Premium upgrade screen. If a Premium owner attempts to add an eleventh invited member, show the extra-seat price before confirming the invitation. The charge belongs only to the owner; no other member is asked to pay.')

heading('Navigation and UI Direction', 1)
add_table(
    ['Tab', 'Suggested icon', 'Purpose'],
    [
        ['Members', 'groups', 'Invite and manage family members, status, and permissions.'],
        ['Location', 'location_on', 'Map and approved family location sharing.'],
        ['Home', 'home', 'Raised central circular tab with the daily overview and SOS action.'],
        ['Plan', 'workspace_premium', 'Plan comparison, seat usage, billing, and upgrade.'],
        ['Profile', 'person', 'Profile photo, personal details, settings, theme, and logout.'],
    ],
    [1.2, 1.6, 3.95],
)
para('The Home tab is larger than the other tabs. It sits in a circular button raised above the top edge of the bottom navigation bar. The bar rises into a smooth curve around Home and returns smoothly to normal height on either side. Use red only for SOS and urgent alerts; the remaining interface should stay calm in charcoal dark mode and off-white light mode.')

heading('Home Screen', 2)
bullet('Safety status at the top, such as “You are safe.”')
bullet('Compact location and battery summary.')
bullet('Family status list with profile photos, relationship, last seen, and relevant alert state.')
bullet('Large SOS action. Prefer press-and-hold over a simple tap to reduce accidental alerts.')

heading('Profile Screen', 2)
bullet('Profile photo: add from camera or gallery, replace, or remove.')
bullet('Name and relationship: editable.')
bullet('Email and phone: read-only with a lock indicator.')
bullet('Save action in the top-right; enabled only after a real change.')
bullet('Leaving with unsaved changes: Keep editing, Discard, or Save.')
bullet('Dark and light theme toggle.')
bullet('Profile photo is stored securely and visible only to authorized family members.')
para('Existing users may have no Firestore document at users slash user ID. Their name and relationship therefore cannot appear until the profile record is created or migrated. New sign-ups should create this record automatically.')

heading('Daily Check in Free Feature', 1)
para('Daily Check-in is a caring welfare feature, not an emergency alert. Opening the app can count as a check-in. Each member decides whether they want to receive missed-check-in notifications about others.')
flow_step('Member opens the app or confirms check-in')
flow_step('System records todays check-in time')
flow_step('Configured deadline passes')
flow_step('System checks members who opted in to notifications')
flow_step('Send calm missed-check-in notification', accent=True)
flow_step('Recipient can Call, Message, or View Profile')
add_table(
    ['Setting', 'Recommended behavior'],
    [
        ['Receive missed check-in notifications', 'Checkbox in settings. Each member chooses yes or no.'],
        ['Deadline', 'Configurable daily time, with a sensible default.'],
        ['Grace period', 'Delay the notice by 1 to 2 hours to reduce false alarms.'],
        ['Pause', 'Allow travel, holiday, or temporary pause.'],
        ['Message', '“Ali ka aaj ka check-in receive nahi hua. Unhein call karke khairiyat pooch lein.”'],
    ],
    [2.0, 4.75],
)

heading('Premium Device Monitoring', 1)
para('Premium monitoring applies only when a member has joined the owner\'s Premium Family Circle and granted explicit permission. It should never claim certainty where the app only has incomplete device information.')
add_table(
    ['Signal', 'User facing wording', 'Alert action'],
    [
        ['Low battery', 'Battery is at 5 percent.', 'Notify approved members once, with cooldown.'],
        ['No heartbeat', 'Device offline. Last seen 12 minutes ago.', 'Notify approved members after a grace period.'],
        ['Location permission changed', 'Location sharing paused.', 'Notify only the member and approved circle contacts.'],
        ['SOS', 'Emergency alert from member.', 'Push alert, optional SMS fallback, and tap-to-call action.'],
    ],
    [1.35, 2.7, 2.7],
)
para('Do not label a no-heartbeat condition as “phone switched off.” A phone can be offline for many reasons. Use “Device offline” and show the latest known time instead. Automatic calls should not be the default; use user-controlled push alerts, SMS fallback, and a tap-to-call action.')

heading('Permissions and Privacy', 1)
bullet('Every member explicitly approves their profile photo, location, battery, notification, and background monitoring choices.')
bullet('Members can revoke sharing at any time. The app then displays “Location sharing paused” rather than hidden or misleading data.')
bullet('The platform stores only the minimum needed information, protects access with Firebase security rules, and keeps an alert audit history.')
bullet('Notifications use calm wording for welfare checks and urgent wording only for SOS or confirmed emergency workflows.')

heading('Implementation Roadmap', 1)
add_table(
    ['Phase', 'Scope', 'Outcome'],
    [
        ['1', 'Finalize visual style and curved five-tab navigation.', 'A polished, reviewable UI foundation.'],
        ['2', 'Fix profile data for existing users; add editable profile, profile photo, and Firestore Storage.', 'Every user sees their correct identity.'],
        ['3', 'Create Family Circle, invitations, member limits, Free and Premium seat enforcement.', 'Clear subscription ownership and billing logic.'],
        ['4', 'Build Daily Check-in, deadlines, notification opt-in, and server scheduling.', 'Useful Free safety feature.'],
        ['5', 'Build Premium consent, location, battery heartbeat, offline alerts, and alert history.', 'Reliable Premium monitoring.'],
        ['6', 'Add payment provider, billing lifecycle, extra seats, and cancellation/upgrade testing.', 'Production-ready commercial plan.'],
    ],
    [0.75, 3.7, 2.3],
)

heading('Open Decisions for Review', 1)
bullet('Premium monthly price and the per-extra-member monthly price.')
bullet('Whether Free allows 2 invited members or 2 total people including the owner. Recommendation: owner plus 2 invited members.')
bullet('Default Daily Check-in deadline and grace period.')
bullet('Who receives each alert: all family members, selected contacts, or an owner-managed alert group.')
bullet('Whether SMS fallback is included in Premium or charged separately per message.')

doc.save(OUT)
print(OUT)
