# TinySteps — Dashboard & Feature Planning
**Role-based dashboards with full working specs**
*Session: 2026-03-16 | Sunrise Theme | Flutter + Supabase*

---

## Architecture Overview

```
lib/features/
├── admin/
│   ├── screens/
│   │   ├── admin_home_screen.dart       ← Dashboard home
│   │   ├── users_screen.dart            ← Manage teachers/parents
│   │   ├── classrooms_screen.dart       ← Manage classrooms
│   │   ├── children_screen.dart         ← View all children
│   │   ├── attendance_report_screen.dart
│   │   ├── referral_codes_screen.dart   ← Generate/manage codes
│   │   └── admin_settings_screen.dart
│   └── widgets/
├── teacher/
│   ├── screens/
│   │   ├── teacher_home_screen.dart     ← Dashboard home
│   │   ├── my_classroom_screen.dart     ← Children in classroom
│   │   ├── attendance_screen.dart       ← QR scan + mark attendance
│   │   ├── child_detail_screen.dart     ← View child profile
│   │   └── teacher_settings_screen.dart
│   └── widgets/
└── parent/
    ├── screens/
    │   ├── parent_home_screen.dart      ← Dashboard home
    │   ├── child_profile_screen.dart    ← View/edit child
    │   ├── add_child_screen.dart        ← Add more children
    │   ├── attendance_history_screen.dart
    │   └── parent_settings_screen.dart
    └── widgets/
```

---

## Navigation — Per Role

All roles use a **floating bottom nav bar** (pill style, Sunrise themed).

| Tab | Admin | Teacher | Parent |
|-----|-------|---------|--------|
| 1 | 🏠 Dashboard | 🏠 Dashboard | 🏠 Dashboard |
| 2 | 👥 Users | 🧒 Classroom | 🧒 My Children |
| 3 | 🏫 Classrooms | 📋 Attendance | 📋 Attendance |
| 4 | ⚙️ Settings | ⚙️ Settings | ⚙️ Settings |

---

## 🛡️ Admin Dashboard

### Tab 1 — Home Dashboard

**UI Layout:**
- Greeting card: time-aware `"Good morning/afternoon/evening/night, [Name]"` with center name
  - 05:00–11:59 → Good morning 🌅
  - 12:00–14:59 → Good afternoon ☀️
  - 15:00–17:59 → Good evening 🌇
  - 18:00–04:59 → Good night 🌙
- **Stats row** (4 cards in 2×2 grid):
  - Total Teachers | Pending Approvals
  - Total Parents | Total Children
- **Alert section** — Teachers pending approval (action: Approve / Reject)
- **Quick actions** row:
  - Generate Referral Code
  - Add Classroom
  - View Attendance Report

**Data sources:**
```sql
SELECT COUNT(*) FROM teachers WHERE is_approved = false  -- pending
SELECT COUNT(*) FROM teachers WHERE is_active = true
SELECT COUNT(*) FROM parents WHERE is_active = true
SELECT COUNT(*) FROM children
```

**Business logic:**
- Admin can approve/reject teachers directly from home card
- Approving sets `teachers.is_approved = true`
- Rejecting sets `teachers.is_active = false` and sends email (future)

---

### Tab 2 — Users Management

**Two sub-tabs: Teachers | Parents**

**Teachers list:**
- Name, designation, staff ID, join date
- Status badge: `Pending` (amber) / `Active` (green) / `Inactive` (grey)
- Tap → teacher detail sheet:
  - View all info
  - Toggle approval
  - Assign to classroom (dropdown of existing classrooms)

**Parents list:**
- Name, phone, number of children
- Tap → parent detail sheet:
  - View info + emergency contact
  - View linked children

**DB operations:**
```dart
// Approve teacher
supabase.from('teachers').update({'is_approved': true}).eq('id', teacherId)

// Assign teacher to classroom
supabase.from('classrooms').update({'teacher_id': tid}).eq('id', classroomId)
// Also update children in that classroom
supabase.from('children').update({'teacher_id': tid}).eq('classroom_id', classroomId)
```

---

### Tab 3 — Classrooms

**List view:**
- Classroom name, age group, teacher name, child count vs capacity
- Progress bar: capacity usage
- Add classroom FAB

**Classroom detail:**
- Edit name/age group/capacity
- Change assigned teacher (dropdown)
- Children list for this classroom
- Assign children: select from unassigned children pool

**DB operations:**
```dart
// Get classrooms with teacher name + child count
supabase.from('classrooms')
  .select('*, teachers(full_name), children(count)')

// Assign child to classroom
supabase.from('children').update({
  'classroom_id': classroomId,
  'teacher_id': teacherId,  // cache for perf
}).eq('id', childId)
```

---

### Tab 4 — Admin Settings

**UI Layout:**
- **Profile Card**: Avatar, Name, Email, and 'Administrator' badge.
- **App Preferences**: 
  - Toggle: Push Notifications
  - Toggle: Dark Mode (Sync with `AppSettingsController`)
- **Daycare Management**:
  - Edit Daycare Profile (Name, Logo, Address)
  - Roles & Permissions
  - Subscription Management
- **Support & Legal**: FAQ, Privacy Policy, Terms of Service.
- **Account Actions**: Change Password, Sign Out (with confirmation dialog).

**Business logic:**
- Sign out clears Supabase session and redirects to Login.
- Dark mode toggle updates global theme state.
- Daycare profile updates the `daycare_info` table.

### Referral Codes (Quick action → modal sheet)

- Generate new code for a role (parent/teacher/admin)
- Set expiry date
- Copy to clipboard
- View all codes with status (used/active/expired)

```dart
// Generate code
final code = 'TINY-${Random().nextInt(9000) + 1000}';
supabase.from('referral_codes').insert({
  'code': code,
  'role': selectedRole,
  'expires_at': expiryDate.toIso8601String(),
  'created_by': currentAdminId,
});
```

---

## 👩‍🏫 Teacher Dashboard

### Tab 1 — Home Dashboard

**UI Layout:**
- Time-aware greeting (same morning/afternoon/evening/night logic) + today's date
- **Today's summary card:**
  - X children expected | Y checked in | Z checked out
- **Quick action:** Big coral "Scan QR Check-In" button
- **Absent today list** — children not yet checked in (with parent phone tap-to-call)

**Data sources:**
```sql
-- Today's attendance for teacher's classroom
SELECT c.full_name, a.checked_in_at, a.checked_out_at
FROM children c
LEFT JOIN attendance a ON a.child_id = c.id AND a.date = CURRENT_DATE
WHERE c.teacher_id = auth.uid()
ORDER BY c.full_name
```

---

### Tab 2 — My Classroom

**Children list:**
- Avatar (initials circle, Sunrise colored)
- Name, age (calculated from DOB)
- Status chip: `Checked In` / `Checked Out` / `Absent`
- Tap → child detail sheet:
  - Full profile (name, DOB, gender, allergies, medical notes)
  - Emergency contact (parent name + phone — tap to call)
  - Today's attendance status
  - Mark present manually (if QR fails)

**Teacher cannot:**
- Edit child data (read-only)
- See parent personal info beyond emergency contact

---

### Tab 3 — Attendance (QR Scanner)

**Flow:**
1. Teacher taps "Scan QR"
2. Camera opens (mobile_scanner package)
3. Parent shows QR code from their app
4. QR contains `child_id` (UUID)
5. App validates child belongs to this teacher's classroom
6. Inserts/updates attendance record
7. Success animation + child name shown

**QR content format:**
```json
{ "child_id": "uuid-here", "type": "checkin" }
```

**DB operation:**
```dart
// Check-in
supabase.from('attendance').upsert({
  'child_id': childId,
  'date': DateTime.now().toIso8601String().split('T').first,
  'checked_in_at': DateTime.now().toIso8601String(),
  'checked_in_by': teacherId,
  'method': 'qr',
}, onConflict: 'child_id,date');
```

**Manual mark (fallback):**
- Teacher can manually mark from classroom list if QR fails

---

## 👨‍👩‍👧 Parent Dashboard

### Tab 1 — Home Dashboard

**UI Layout:**
- Time-aware greeting: "Good morning/afternoon/evening/night, [Parent Name]!"
- **Child cards** (scrollable horizontal if multiple children):
  - Child avatar (initials circle)
  - Name + age
  - **Today's status**: `At Home` / `Checked In ✅` / `Checked Out 🏃`
  - Check-in time if present
- **QR code button** — "Show QR for check-in" → big QR code display
- **Today's quick info:**
  - Teacher name + contact
  - Classroom name

**QR generation:**
```dart
// Generate QR from child_id using qr_flutter package
QrImageView(
  data: jsonEncode({'child_id': child.id, 'type': 'checkin'}),
  size: 240,
  backgroundColor: Colors.white,
)
```

---

### Tab 2 — My Children

**List of all children:**
- Card for each child with name, DOB, classroom assigned
- "Add Child" FAB (→ add_child_screen, same form as signup step 2)
- Tap → child_profile_screen:
  - Edit child details (name, DOB, gender, allergies, medical notes)
  - View assigned classroom + teacher
  - **Cannot** reassign classroom (admin only)

**Add child form (same as signup Step 2):**
- Full name, DOB, gender, allergies, medical notes
- On submit → insert to `children` table with `parent_id = currentUser.id`
- Awaits admin to assign classroom + teacher

---

### Tab 3 — Attendance History

**Per-child attendance log:**
- Child selector (tab or dropdown if multiple children)
- Calendar view or list view (toggle)
- Each day: check-in time, check-out time, method (QR/manual), teacher name
- Monthly summary: total days present / total school days

**DB:**
```sql
SELECT a.date, a.checked_in_at, a.checked_out_at, a.method,
       t.full_name as teacher_name
FROM attendance a
JOIN children c ON c.id = a.child_id
LEFT JOIN teachers t ON t.id = a.checked_in_by
WHERE c.parent_id = auth.uid()
ORDER BY a.date DESC
```

---

## Shared Components to Build

| Component | Used by | Description |
|-----------|---------|-------------|
| [ChildAvatar](file:///d:/Internship/project1/tinysteps/lib/features/parent/screens/parent_home_screen.dart#80-103) | All | Initials circle with Sunrise color per child |
| `StatusChip` | Teacher, Parent | Colour-coded status badge |
| `SectionHeader` | All | Title + optional action button |
| `AttendanceCard` | Teacher, Parent | Single day attendance tile |
| [StatCard](file:///d:/Internship/project1/tinysteps/lib/features/admin/screens/admin_home_screen.dart#76-118) | Admin, Teacher | Number + label + icon card |
| `BottomNavBar` | All | Floating pill-style bottom nav |
| `QRDisplaySheet` | Parent | Full-screen QR code bottom sheet |
| `QRScannerView` | Teacher | Camera scanner with overlay |
| `EmptyState` | All | Illustration + message when no data |

---

## Packages Needed (to add)

| Package | Purpose |
|---------|---------|
| `mobile_scanner` | Camera QR scanning (teacher) |
| `qr_flutter` | QR code rendering (parent) |
| `table_calendar` | Attendance calendar view (parent) |
| `url_launcher` | Tap-to-call emergency contact (teacher) |
| `intl` | Date formatting |

```bash
flutter pub add mobile_scanner qr_flutter table_calendar url_launcher intl
```

---

## Admin Controls Summary

| Action | Who can do it |
|--------|--------------|
| Approve/reject teacher | Admin only |
| Create classrooms | Admin only |
| Assign teacher to classroom | Admin only |
| Assign child to classroom | Admin only |
| Generate referral codes | Admin only |
| View all users & children | Admin only |
| Mark attendance | Teacher only |
| View QR for check-in | Parent only |
| Add/edit own child profile | Parent (with admin oversight) |
| View attendance history | Parent (own children) + Admin |

---

## Implementation Order for Interns

### Week 1 — Shared components + Admin
1. `BottomNavBar` widget (shared)
2. [StatCard](file:///d:/Internship/project1/tinysteps/lib/features/admin/screens/admin_home_screen.dart#76-118), `SectionHeader`, [ChildAvatar](file:///d:/Internship/project1/tinysteps/lib/features/parent/screens/parent_home_screen.dart#80-103), `StatusChip`, `EmptyState`
3. [admin_home_screen.dart](file:///d:/Internship/project1/tinysteps/lib/features/admin/screens/admin_home_screen.dart) — stats + pending approvals
4. `users_screen.dart` — teacher list + approval flow
5. `classrooms_screen.dart` — CRUD classrooms
6. `referral_codes_screen.dart` — generate + manage codes

### Week 2 — Teacher dashboard
1. [teacher_home_screen.dart](file:///d:/Internship/project1/tinysteps/lib/features/teacher/screens/teacher_home_screen.dart) — daily summary
2. `my_classroom_screen.dart` — children list
3. `attendance_screen.dart` — QR scanner integration
4. `child_detail_screen.dart` — read-only child view

### Week 3 — Parent dashboard
1. [parent_home_screen.dart](file:///d:/Internship/project1/tinysteps/lib/features/parent/screens/parent_home_screen.dart) — child cards + QR button
2. `child_profile_screen.dart` — edit child details
3. `add_child_screen.dart` — add more children
4. `attendance_history_screen.dart` — calendar + list

### Week 4 — Polish & Testing
1. Dark mode all screens
2. Empty states & error handling
3. Loading skeletons
4. End-to-end test: Parent signup → Admin approves → Teacher scans → Parent sees attendance

---

## Data Flow Diagram

```
Parent signs up
    │
    ├─▶ parents table (trigger)
    └─▶ children table (trigger — first child)
              │
              ▼
        Admin assigns classroom + teacher
              │
              ▼
        Teacher's classroom_screen shows child
              │
              ▼
        Parent shows QR → Teacher scans it
              │
              ▼
        attendance table record created
              │
              ├─▶ Teacher sees: Checked In ✅
              └─▶ Parent sees: At School ✅
```
