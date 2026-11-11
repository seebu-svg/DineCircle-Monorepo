/* ==========================================================================
   DineCircle Admin — mock dataset
   Prototype-only fixtures. Everything here is synthetic and stored in the
   browser; nothing is sent to the API. Shapes intentionally mirror the
   server tables (users, restaurants, subscriptions, dinner_events, ...) so
   this can be swapped for fetch() calls without touching the views.
   ========================================================================== */

const DAY = 86400000;
export const NOW = Date.now();
export const daysAgo = (n) => new Date(NOW - n * DAY).toISOString();
export const daysAhead = (n) => new Date(NOW + n * DAY).toISOString();

export const plans = [
  { id: "pro-monthly", name: "Partner Pro Monthly", price: 5000, cycle: "month", commission: 0 },
  { id: "pro-annual", name: "Partner Pro Annual", price: 50000, cycle: "year", commission: 0 },
];

export const admins = [
  { id: "adm-1", name: "Ayesha Siddiqui", email: "ayesha@dinecircle.app", role: "Super admin", scope: "Full platform", lastActive: daysAgo(0) },
  { id: "adm-2", name: "Bilal Ahmed", email: "bilal@dinecircle.app", role: "Operations admin", scope: "Partners and venues", lastActive: daysAgo(0) },
  { id: "adm-3", name: "Hira Malik", email: "hira@dinecircle.app", role: "Trust and safety", scope: "Reports, content, hosts", lastActive: daysAgo(1) },
  { id: "adm-4", name: "Danish Qureshi", email: "danish@dinecircle.app", role: "Finance admin", scope: "Subscriptions and receipts", lastActive: daysAgo(3) },
  { id: "adm-5", name: "Zara Iqbal", email: "zara@dinecircle.app", role: "Support admin", scope: "Customers and hosts", lastActive: daysAgo(6) },
];

export const applications = [
  {
    id: "APP-1084", restaurant: "Sajjad's Charcoal Grill", contact: "Sajjad Ali", email: "sajjad@charcoalgrill.pk", phone: "+92 321 2245566",
    area: "Gulshan-e-Iqbal, Karachi", cuisines: ["BBQ", "Pakistani"], submitted: daysAgo(0), status: "pending", plan: "pro-monthly",
    documents: ["CNIC", "NTN certificate", "Lease agreement"], seats: 74, note: "Family BBQ hall with an existing 6,000 follower Instagram page. Interested in the monthly plan and a QR menu for four sections.",
  },
  {
    id: "APP-1083", restaurant: "Sakura Sushi House", contact: "Mehreen Tan", email: "mehreen@sakurasushi.pk", phone: "+92 300 7712001",
    area: "Clifton Block 4, Karachi", cuisines: ["Japanese", "Sushi"], submitted: daysAgo(1), status: "in_review", plan: "pro-annual",
    documents: ["CNIC", "NTN certificate", "Food licence"], seats: 42, note: "New venue, two months old. Requesting verification visit before activation. Annual payment receipt uploaded.",
  },
  {
    id: "APP-1082", restaurant: "Chai Khana Tariq Road", contact: "Usman Raza", email: "usman@chaikhana.pk", phone: "+92 333 9087120",
    area: "Tariq Road, Karachi", cuisines: ["Cafe", "Desserts"], submitted: daysAgo(2), status: "pending", plan: "pro-monthly",
    documents: ["CNIC", "NTN certificate"], seats: 36, note: "Late-night chai cafe. Documents reviewed but the lease agreement is still missing.",
  },
  {
    id: "APP-1081", restaurant: "Biryani Junction", contact: "Faisal Memon", email: "faisal@biryani-junction.pk", phone: "+92 345 1120934",
    area: "North Nazimabad, Karachi", cuisines: ["Pakistani", "Biryani"], submitted: daysAgo(3), status: "pending", plan: "pro-monthly",
    documents: ["CNIC", "NTN certificate", "Food licence"], seats: 58, note: "High delivery volume, wants dine-in discovery and deals for weekday lunch.",
  },
  {
    id: "APP-1080", restaurant: "The Piano Lounge", contact: "Nadia Farooq", email: "nadia@pianolounge.pk", phone: "+92 302 6604411",
    area: "DHA Phase 6, Karachi", cuisines: ["Continental", "Live music"], submitted: daysAgo(4), status: "in_review", plan: "pro-annual",
    documents: ["CNIC", "NTN certificate", "Lease agreement"], seats: 90, note: "Wants to co-host jazz dining experiences. Awaiting confirmation of the music licence.",
  },
  {
    id: "APP-1079", restaurant: "Bun & Bean Bakers", contact: "Sara Khan", email: "sara@bunandbean.pk", phone: "+92 311 4478902",
    area: "Bahadurabad, Karachi", cuisines: ["Bakery", "Cafe"], submitted: daysAgo(6), status: "pending", plan: "pro-monthly",
    documents: ["CNIC", "Food licence"], seats: 28, note: "Bakery counter plus 20 seats. Receipt unreadable, needs a re-upload before verification.",
  },
  {
    id: "APP-1078", restaurant: "Coastal Catch", contact: "Imran Baloch", email: "imran@coastalcatch.pk", phone: "+92 300 5590187",
    area: "Do Darya, Karachi", cuisines: ["Seafood", "Grill"], submitted: daysAgo(8), status: "approved", plan: "pro-annual",
    documents: ["CNIC", "NTN certificate", "Lease agreement"], seats: 110, note: "Approved after verification visit on 3 November. Annual payment confirmed.",
  },
  {
    id: "APP-1077", restaurant: "Slice of Napoli", contact: "Marco Ricci", email: "marco@sliceofnapoli.pk", phone: "+92 315 2203311",
    area: "Zamzama, Karachi", cuisines: ["Italian", "Pizza"], submitted: daysAgo(11), status: "rejected", plan: "pro-monthly",
    documents: ["CNIC"], seats: 40, note: "Rejected: food licence expired and the contact number did not answer three verification calls.",
  },
];

export const restaurants = [
  {
    id: "RST-101", name: "Kolachi Restaurant", owner: "Coastal Dining (Pvt) Ltd", ownerEmail: "ops@kolachi.pk",
    area: "Do Darya, DHA Phase 8", cuisines: ["Pakistani", "Seafood", "BBQ"], status: "active", verified: true,
    plan: "pro-annual", joined: daysAgo(412), views: 18240, bookings: 46, rating: 4.7,
    contact: "+92 21 3585 5000", note: "Anchor partner. Featured on the website restaurant directory.",
  },
  {
    id: "RST-102", name: "Kababjees", owner: "Kababjees Restaurants", ownerEmail: "partners@kababjees.com",
    area: "Shaheed-e-Millat, Karachi", cuisines: ["BBQ", "Pakistani"], status: "active", verified: true,
    plan: "pro-monthly", joined: daysAgo(365), views: 15980, bookings: 39, rating: 4.5,
    contact: "+92 21 111 222 333", note: "Multi-branch enquiry pending for the next phase.",
  },
  {
    id: "RST-103", name: "Bar B Q Tonight", owner: "BBQ Tonight Pvt Ltd", ownerEmail: "brand@bbqtonight.com",
    area: "Boat Basin, Karachi", cuisines: ["BBQ", "Pakistani"], status: "active", verified: true,
    plan: "pro-annual", joined: daysAgo(340), views: 14210, bookings: 33, rating: 4.4,
    contact: "+92 21 111 227 666", note: "Deals live for weekday lunch.",
  },
  {
    id: "RST-104", name: "Cafe Aylanto", owner: "Aylanto Hospitality", ownerEmail: "manager@aylanto.pk",
    area: "Zamzama, DHA Phase 5", cuisines: ["Continental", "Mediterranean"], status: "active", verified: true,
    plan: "pro-annual", joined: daysAgo(310), views: 12030, bookings: 28, rating: 4.6,
    contact: "+92 21 3583 6666", note: "Hosts monthly chef table experiences.",
  },
  {
    id: "RST-105", name: "Okra", owner: "Okra Karachi", ownerEmail: "hello@okra.pk",
    area: "Clifton Block 5, Karachi", cuisines: ["Mediterranean", "Continental"], status: "active", verified: true,
    plan: "pro-monthly", joined: daysAgo(288), views: 9840, bookings: 21, rating: 4.5,
    contact: "+92 21 3537 4023", note: "Photo gallery refresh requested.",
  },
  {
    id: "RST-106", name: "Xander's", owner: "Xanders Cafe Ltd", ownerEmail: "team@xanders.pk",
    area: "Clifton Block 7, Karachi", cuisines: ["Breakfast", "Cafe"], status: "active", verified: true,
    plan: "pro-monthly", joined: daysAgo(266), views: 8760, bookings: 18, rating: 4.3,
    contact: "+92 21 3586 2265", note: "Weekend brunch deal is the top redeemed offer.",
  },
  {
    id: "RST-107", name: "Espresso Shahbaz DHA", owner: "Espresso Coffee House", ownerEmail: "dha@espresso.pk",
    area: "DHA Phase 2, Karachi", cuisines: ["Coffee", "Cafe"], status: "active", verified: true,
    plan: "pro-monthly", joined: daysAgo(240), views: 7420, bookings: 12, rating: 4.2,
    contact: "+92 21 3531 7788", note: "Subscription renews in 6 days.",
  },
  {
    id: "RST-108", name: "Cafe Flo", owner: "Flo Hospitality", ownerEmail: "hi@cafeflo.pk",
    area: "Khayaban-e-Shahbaz, Karachi", cuisines: ["Cafe", "Desserts"], status: "active", verified: true,
    plan: "pro-annual", joined: daysAgo(218), views: 6890, bookings: 16, rating: 4.4,
    contact: "+92 21 3584 1120", note: "Featured on the website cafe collection.",
  },
  {
    id: "RST-109", name: "Butlers Chocolate Cafe", owner: "Butlers Pakistan", ownerEmail: "franchise@butlers.pk",
    area: "Dolmen Mall Clifton, Karachi", cuisines: ["Desserts", "Coffee"], status: "active", verified: true,
    plan: "pro-monthly", joined: daysAgo(196), views: 6210, bookings: 9, rating: 4.1,
    contact: "+92 21 3529 4400", note: "",
  },
  {
    id: "RST-110", name: "Esquires Coffee", owner: "Esquires Karachi", ownerEmail: "karachi@esquires.pk",
    area: "Bahadurabad, Karachi", cuisines: ["Coffee", "Breakfast"], status: "pending", verified: false,
    plan: "pro-monthly", joined: daysAgo(4), views: 210, bookings: 0, rating: 0,
    contact: "+92 21 3499 1200", note: "Awaiting site verification and first menu upload.",
  },
  {
    id: "RST-111", name: "Cafe Zouk", owner: "Zouk Leisure", ownerEmail: "info@cafezouk.pk",
    area: "Bukhari Commercial, Karachi", cuisines: ["Continental", "Cafe"], status: "pending", verified: false,
    plan: "pro-monthly", joined: daysAgo(6), views: 160, bookings: 0, rating: 0,
    contact: "+92 21 3589 0033", note: "Application approved, onboarding not started.",
  },
  {
    id: "RST-112", name: "The Village", owner: "Village Karachi", ownerEmail: "hello@thevillage.pk",
    area: "Abdul Sattar Edhi Road, Karachi", cuisines: ["BBQ", "Desi"], status: "suspended", verified: true,
    plan: "pro-monthly", joined: daysAgo(152), views: 4120, bookings: 6, rating: 3.6,
    contact: "+92 21 3489 7766", note: "Suspended after three unresolved guest reports about advertised prices.",
  },
  {
    id: "RST-113", name: "Salt & Pepper Bistro", owner: "S&P Foods", ownerEmail: "care@saltpepper.pk",
    area: "Gulshan Block 6, Karachi", cuisines: ["Fast food", "Continental"], status: "suspended", verified: false,
    plan: "pro-monthly", joined: daysAgo(64), views: 2380, bookings: 3, rating: 3.2,
    contact: "+92 21 3492 5566", note: "Payment receipt rejected twice. Venue hidden from customer app.",
  },
  {
    id: "RST-114", name: "Dhaba 44", owner: "Dhaba 44 Karachi", ownerEmail: "dhaba44@outlook.com",
    area: "Korangi Road, Karachi", cuisines: ["Desi", "BBQ"], status: "draft", verified: false,
    plan: "pro-monthly", joined: daysAgo(12), views: 0, bookings: 0, rating: 0,
    contact: "+92 300 9988112", note: "Created by admin at the partner's request. Waiting for owner login.",
  },
];

export const partnerAccounts = [
  { id: "PA-201", name: "Hassan Raza", email: "hassan@kolachi.pk", role: "Partner owner", restaurants: ["Kolachi Restaurant"], status: "active", lastActive: daysAgo(0), twoFactor: true },
  { id: "PA-202", name: "Nida Sheikh", email: "nida@kolachi.pk", role: "Venue manager", restaurants: ["Kolachi Restaurant"], status: "active", lastActive: daysAgo(1), twoFactor: true },
  { id: "PA-203", name: "Kamran Ali", email: "kamran@kababjees.com", role: "Partner owner", restaurants: ["Kababjees"], status: "active", lastActive: daysAgo(0), twoFactor: false },
  { id: "PA-204", name: "Farah Noor", email: "farah@kababjees.com", role: "Reservations staff", restaurants: ["Kababjees"], status: "active", lastActive: daysAgo(2), twoFactor: false },
  { id: "PA-205", name: "Adil Rehman", email: "adil@bbqtonight.com", role: "Partner owner", restaurants: ["Bar B Q Tonight"], status: "active", lastActive: daysAgo(0), twoFactor: true },
  { id: "PA-206", name: "Sana Tariq", email: "sana@aylanto.pk", role: "Venue manager", restaurants: ["Cafe Aylanto"], status: "active", lastActive: daysAgo(3), twoFactor: true },
  { id: "PA-207", name: "Omar Yousuf", email: "omar@okra.pk", role: "Partner owner", restaurants: ["Okra"], status: "active", lastActive: daysAgo(5), twoFactor: false },
  { id: "PA-208", name: "Rida Aslam", email: "rida@xanders.pk", role: "Partner owner", restaurants: ["Xander's"], status: "invited", lastActive: null, twoFactor: false },
  { id: "PA-209", name: "Junaid Akhtar", email: "junaid@thevillage.pk", role: "Partner owner", restaurants: ["The Village"], status: "suspended", lastActive: daysAgo(9), twoFactor: false },
  { id: "PA-210", name: "Mehwish Baig", email: "mehwish@saltpepper.pk", role: "Partner owner", restaurants: ["Salt & Pepper Bistro"], status: "suspended", lastActive: daysAgo(21), twoFactor: false },
];

export const subscriptions = [
  { id: "SUB-9041", partner: "Kolachi Restaurant", account: "Hassan Raza", plan: "pro-annual", amount: 50000, method: "Bank transfer", reference: "HBL-8841209", status: "active", started: daysAgo(320), expires: daysAhead(45), receipt: "hbl-8841209.pdf" },
  { id: "SUB-9042", partner: "Kababjees", account: "Kamran Ali", plan: "pro-monthly", amount: 5000, method: "JazzCash", reference: "JC-77120934", status: "active", started: daysAgo(26), expires: daysAhead(4), receipt: "jazzcash-nov.jpg" },
  { id: "SUB-9043", partner: "Bar B Q Tonight", account: "Adil Rehman", plan: "pro-annual", amount: 50000, method: "Bank transfer", reference: "MCB-5590112", status: "active", started: daysAgo(290), expires: daysAhead(75), receipt: "mcb-5590112.pdf" },
  { id: "SUB-9044", partner: "Cafe Aylanto", account: "Sana Tariq", plan: "pro-annual", amount: 50000, method: "Bank transfer", reference: "UBL-3320198", status: "active", started: daysAgo(210), expires: daysAhead(155), receipt: "ubl-3320198.pdf" },
  { id: "SUB-9045", partner: "Okra", account: "Omar Yousuf", plan: "pro-monthly", amount: 5000, method: "Easypaisa", reference: "EP-44120977", status: "awaiting_verification", started: null, expires: null, receipt: "easypaisa-nov10.png" },
  { id: "SUB-9046", partner: "Xander's", account: "Rida Aslam", plan: "pro-monthly", amount: 5000, method: "JazzCash", reference: "JC-90023881", status: "awaiting_verification", started: null, expires: null, receipt: "jazzcash-receipt.png" },
  { id: "SUB-9047", partner: "Espresso Shahbaz DHA", account: "Espresso Coffee House", plan: "pro-monthly", amount: 5000, method: "Bank transfer", reference: "HBL-9920183", status: "expiring", started: daysAgo(24), expires: daysAhead(6), receipt: "hbl-9920183.pdf" },
  { id: "SUB-9048", partner: "Cafe Flo", account: "Flo Hospitality", plan: "pro-annual", amount: 50000, method: "Bank transfer", reference: "MCB-1120445", status: "active", started: daysAgo(180), expires: daysAhead(185), receipt: "mcb-1120445.pdf" },
  { id: "SUB-9049", partner: "Butlers Chocolate Cafe", account: "Butlers Pakistan", plan: "pro-monthly", amount: 5000, method: "Easypaisa", reference: "EP-33881129", status: "expired", started: daysAgo(66), expires: daysAgo(5), receipt: "easypaisa-oct.png" },
  { id: "SUB-9050", partner: "Esquires Coffee", account: "Esquires Karachi", plan: "pro-monthly", amount: 5000, method: "Bank transfer", reference: "UBL-7712099", status: "expired", started: daysAgo(40), expires: daysAgo(9), receipt: "ubl-7712099.pdf" },
  { id: "SUB-9051", partner: "Cafe Zouk", account: "Zouk Leisure", plan: "pro-monthly", amount: 5000, method: "JazzCash", reference: "JC-6650123", status: "rejected", started: null, expires: null, receipt: "blurry-screenshot.jpg" },
  { id: "SUB-9052", partner: "The Village", account: "Junaid Akhtar", plan: "pro-monthly", amount: 5000, method: "Easypaisa", reference: "EP-11209834", status: "active", started: daysAgo(20), expires: daysAhead(10), receipt: "easypaisa-nov1.png" },
];

export const customers = [
  { id: "CUS-7001", name: "Amna Khalid", email: "amna.khalid@gmail.com", city: "Karachi", joined: daysAgo(210), bookings: 14, reviews: 9, status: "active", issues: 0, lastActive: daysAgo(1) },
  { id: "CUS-7002", name: "Bilal Hussain", email: "bilal.h@outlook.com", city: "Karachi", joined: daysAgo(188), bookings: 9, reviews: 4, status: "active", issues: 0, lastActive: daysAgo(0) },
  { id: "CUS-7003", name: "Sana Mirza", email: "sana.mirza@yahoo.com", city: "Karachi", joined: daysAgo(160), bookings: 6, reviews: 7, status: "flagged", issues: 2, lastActive: daysAgo(2), issueNote: "Two reviews reported for abusive language toward venue staff." },
  { id: "CUS-7004", name: "Hamza Sheikh", email: "hamza.sheikh@gmail.com", city: "Karachi", joined: daysAgo(142), bookings: 21, reviews: 12, status: "active", issues: 0, lastActive: daysAgo(0) },
  { id: "CUS-7005", name: "Zoya Aslam", email: "zoya.aslam@gmail.com", city: "Karachi", joined: daysAgo(130), bookings: 3, reviews: 1, status: "active", issues: 0, lastActive: daysAgo(12) },
  { id: "CUS-7006", name: "Fahad Iqbal", email: "fahad.iqbal@gmail.com", city: "Lahore", joined: daysAgo(121), bookings: 0, reviews: 0, status: "suspended", issues: 3, lastActive: daysAgo(30), issueNote: "Suspended for repeated no-shows across three reservations." },
  { id: "CUS-7007", name: "Mariam Javed", email: "mariam.javed@gmail.com", city: "Karachi", joined: daysAgo(112), bookings: 8, reviews: 5, status: "active", issues: 0, lastActive: daysAgo(3) },
  { id: "CUS-7008", name: "Usman Tariq", email: "usman.tariq@hotmail.com", city: "Karachi", joined: daysAgo(98), bookings: 5, reviews: 2, status: "active", issues: 0, lastActive: daysAgo(6) },
  { id: "CUS-7009", name: "Areeba Fatima", email: "areeba.f@gmail.com", city: "Islamabad", joined: daysAgo(84), bookings: 2, reviews: 3, status: "active", issues: 0, lastActive: daysAgo(4) },
  { id: "CUS-7010", name: "Daniyal Khan", email: "daniyal.khan@gmail.com", city: "Karachi", joined: daysAgo(72), bookings: 7, reviews: 1, status: "flagged", issues: 1, lastActive: daysAgo(1), issueNote: "Flagged for cancelling four experiences inside the 24 hour window." },
  { id: "CUS-7011", name: "Hira Nadeem", email: "hira.nadeem@gmail.com", city: "Karachi", joined: daysAgo(58), bookings: 4, reviews: 6, status: "active", issues: 0, lastActive: daysAgo(2) },
  { id: "CUS-7012", name: "Taimur Baig", email: "taimur.baig@gmail.com", city: "Karachi", joined: daysAgo(45), bookings: 1, reviews: 0, status: "active", issues: 0, lastActive: daysAgo(15) },
  { id: "CUS-7013", name: "Nimra Shah", email: "nimra.shah@gmail.com", city: "Karachi", joined: daysAgo(30), bookings: 3, reviews: 2, status: "active", issues: 0, lastActive: daysAgo(0) },
  { id: "CUS-7014", name: "Ahsan Raza", email: "ahsan.raza@gmail.com", city: "Karachi", joined: daysAgo(18), bookings: 0, reviews: 1, status: "flagged", issues: 1, lastActive: daysAgo(7), issueNote: "Review contains a competitor's promotional link." },
  { id: "CUS-7015", name: "Rabia Anwar", email: "rabia.anwar@gmail.com", city: "Karachi", joined: daysAgo(9), bookings: 1, reviews: 0, status: "active", issues: 0, lastActive: daysAgo(1) },
  { id: "CUS-7016", name: "Saad Yousuf", email: "saad.yousuf@gmail.com", city: "Karachi", joined: daysAgo(3), bookings: 0, reviews: 0, status: "active", issues: 0, lastActive: daysAgo(0) },
];

export const hosts = [
  { id: "HST-501", name: "Ayesha Omar", email: "ayesha.omar@gmail.com", type: "Dining host", city: "Karachi", experiences: 6, guests: 148, rating: 4.8, status: "active", reports: 0, joined: daysAgo(180) },
  { id: "HST-502", name: "Shehryar Munawar", email: "shehryar.m@gmail.com", type: "Food creator", city: "Karachi", experiences: 4, guests: 96, rating: 4.6, status: "active", reports: 0, joined: daysAgo(160) },
  { id: "HST-503", name: "Mawra Hocane", email: "mawra.h@gmail.com", type: "Lifestyle creator", city: "Karachi", experiences: 3, guests: 72, rating: 4.5, status: "active", reports: 1, joined: daysAgo(140), issueNote: "One report claims a promoted experience did not include the advertised tasting menu." },
  { id: "HST-504", name: "Adeel Hussain", email: "adeel.h@gmail.com", type: "Dining host", city: "Karachi", experiences: 5, guests: 110, rating: 4.7, status: "active", reports: 0, joined: daysAgo(120) },
  { id: "HST-505", name: "Mahira Sheikh", email: "mahira.s@gmail.com", type: "Community host", city: "Karachi", experiences: 2, guests: 40, rating: 4.2, status: "paused", reports: 0, joined: daysAgo(96) },
  { id: "HST-506", name: "Wahaj Ali", email: "wahaj.ali@gmail.com", type: "Food creator", city: "Karachi", experiences: 4, guests: 88, rating: 4.4, status: "active", reports: 2, joined: daysAgo(80), issueNote: "Two guests reported late starts and unannounced venue changes." },
  { id: "HST-507", name: "Saba Qamar", email: "saba.q@gmail.com", type: "Lifestyle creator", city: "Lahore", experiences: 1, guests: 24, rating: 3.8, status: "suspended", reports: 3, joined: daysAgo(64), issueNote: "Suspended pending review of three unresolved guest reports." },
  { id: "HST-508", name: "Fawad Khan", email: "fawad.k@gmail.com", type: "Dining host", city: "Karachi", experiences: 2, guests: 36, rating: 4.9, status: "active", reports: 0, joined: daysAgo(40) },
];

export const experiences = [
  { id: "EXP-301", title: "Seafront Sunset Tasting", venue: "Kolachi Restaurant", host: "Ayesha Omar", date: daysAhead(2), seats: 24, booked: 21, price: 6500, status: "live", reports: 0, note: "Seven course seafood tasting on the Do Darya terrace." },
  { id: "EXP-302", title: "Chef's Table: Mediterranean Nights", venue: "Cafe Aylanto", host: "Adeel Hussain", date: daysAhead(5), seats: 16, booked: 16, price: 8500, status: "live", reports: 0, note: "Sold out. Waiting list managed by the venue." },
  { id: "EXP-303", title: "Karachi Street Food Walk", venue: "Bar B Q Tonight", host: "Shehryar Munawar", date: daysAhead(8), seats: 30, booked: 18, price: 3500, status: "pending_review", reports: 0, note: "First experience from this host. Venue and menu confirmed, awaiting content review." },
  { id: "EXP-304", title: "Brunch & Jazz Morning", venue: "Xander's", host: "Mawra Hocane", date: daysAhead(11), seats: 40, booked: 26, price: 4500, status: "flagged", reports: 1, note: "Guest report says the advertised live quartet will not perform." },
  { id: "EXP-305", title: "Biryani Masterclass", venue: "Kababjees", host: "Wahaj Ali", date: daysAhead(14), seats: 20, booked: 9, price: 3000, status: "live", reports: 0, note: "Hands-on cooking session followed by a shared table." },
  { id: "EXP-306", title: "Late Night Chai Stories", venue: "Cafe Flo", host: "Mahira Sheikh", date: daysAhead(18), seats: 25, booked: 7, price: 2000, status: "pending_review", reports: 0, note: "New host collaboration, needs a venue confirmation email." },
  { id: "EXP-307", title: "Rooftop Grill Night", venue: "The Village", host: "Saba Qamar", date: daysAgo(3), seats: 35, booked: 31, price: 5500, status: "cancelled", reports: 3, note: "Cancelled by the venue two hours before start. Guests notified, refunds handled offline." },
  { id: "EXP-308", title: "Coffee Cupping Session", venue: "Espresso Shahbaz DHA", host: "Fawad Khan", date: daysAhead(21), seats: 14, booked: 14, price: 2500, status: "live", reports: 0, note: "Host requested a second date after selling out." },
];

export const deals = [
  { id: "DEAL-601", title: "Weekday Lunch Platter for Two", restaurant: "Bar B Q Tonight", type: "Meal package", value: "Rs. 2,400 for two", redemptions: 184, status: "live", expires: daysAhead(20), reports: 0, note: "" },
  { id: "DEAL-602", title: "20% off all seafood", restaurant: "Kolachi Restaurant", type: "Percentage", value: "20% off", redemptions: 126, status: "live", expires: daysAhead(12), reports: 0, note: "" },
  { id: "DEAL-603", title: "Weekend Brunch for Two", restaurant: "Xander's", type: "Meal package", value: "Rs. 3,200 for two", redemptions: 98, status: "live", expires: daysAhead(30), reports: 0, note: "" },
  { id: "DEAL-604", title: "Free dessert with any karahi", restaurant: "Kababjees", type: "Fixed amount", value: "Rs. 450 off", redemptions: 87, status: "live", expires: daysAhead(9), reports: 0, note: "" },
  { id: "DEAL-605", title: "Buy one coffee, get one free", restaurant: "Espresso Shahbaz DHA", type: "Meal package", value: "2 for 1", redemptions: 64, status: "paused", expires: daysAhead(16), reports: 0, note: "Paused by partner during equipment maintenance." },
  { id: "DEAL-606", title: "Flat Rs. 1,000 off family dinner", restaurant: "The Village", type: "Fixed amount", value: "Rs. 1,000 off", redemptions: 41, status: "flagged", expires: daysAhead(4), reports: 2, note: "Guests report the discount was refused at the venue. Venue suspended." },
  { id: "DEAL-607", title: "Pizza + drink combo", restaurant: "Salt & Pepper Bistro", type: "Meal package", value: "Rs. 1,150 combo", redemptions: 19, status: "flagged", expires: daysAhead(2), reports: 1, note: "Menu item no longer available at the venue." },
  { id: "DEAL-608", title: "Summer dessert festival", restaurant: "Butlers Chocolate Cafe", type: "Percentage", value: "15% off", redemptions: 57, status: "expired", expires: daysAgo(8), reports: 0, note: "" },
];

export const reports = [
  { id: "REP-8801", type: "Venue", subject: "The Village", subjectId: "RST-112", reporter: "Sana Mirza", reason: "Advertised deal price refused at the venue", severity: "high", created: daysAgo(0), status: "open", detail: "Guest reserved through the app, showed the deal code and staff said the offer had ended last week. The deal is still live on the customer app." },
  { id: "REP-8802", type: "Review", subject: "Review on Kolachi Restaurant", subjectId: "REV-4412", reporter: "Hassan Raza", reason: "Abusive language toward staff", severity: "medium", created: daysAgo(0), status: "open", detail: "Partner flagged a one star review that names an individual waiter and uses abusive language. Requesting removal." },
  { id: "REP-8803", type: "Host", subject: "Wahaj Ali", subjectId: "HST-506", reporter: "Multiple guests", reason: "Experience started 80 minutes late", severity: "medium", created: daysAgo(1), status: "in_review", detail: "Two separate guests report the same issue with the Biryani Masterclass on 7 November." },
  { id: "REP-8804", type: "Experience", subject: "Brunch & Jazz Morning", subjectId: "EXP-304", reporter: "Daniyal Khan", reason: "Advertised live music not provided", severity: "medium", created: daysAgo(1), status: "in_review", detail: "Guest says the venue confirmed no quartet was booked for the date." },
  { id: "REP-8805", type: "Customer", subject: "Fahad Iqbal", subjectId: "CUS-7006", reporter: "Kababjees", reason: "Repeated no-shows", severity: "low", created: daysAgo(2), status: "resolved", detail: "Three no-shows in 30 days. Account suspended and guest notified." },
  { id: "REP-8806", type: "Deal", subject: "Flat Rs. 1,000 off family dinner", subjectId: "DEAL-606", reporter: "Amna Khalid", reason: "Discount refused at the venue", severity: "high", created: daysAgo(2), status: "open", detail: "Second report against this deal. Venue already suspended pending a payment review." },
  { id: "REP-8807", type: "Host", subject: "Saba Qamar", subjectId: "HST-507", reporter: "Multiple guests", reason: "Experience cancelled with no notice", severity: "high", created: daysAgo(3), status: "resolved", detail: "Host suspended for 30 days. Guests contacted directly by support." },
  { id: "REP-8808", type: "Venue", subject: "Salt & Pepper Bistro", subjectId: "RST-113", reporter: "Usman Tariq", reason: "Menu items unavailable but still listed", severity: "low", created: daysAgo(4), status: "resolved", detail: "Venue hidden from discovery until the menu is corrected." },
  { id: "REP-8809", type: "Review", subject: "Review on Cafe Flo", subjectId: "REV-4419", reporter: "Cafe Flo", reason: "Competitor promotional link in review", severity: "low", created: daysAgo(5), status: "dismissed", detail: "Reviewed manually. The link was added by a guest account, not the venue." },
  { id: "REP-8810", type: "Customer", subject: "Ahsan Raza", subjectId: "CUS-7014", reporter: "Okra", reason: "Spam review with external link", severity: "low", created: daysAgo(6), status: "open", detail: "Review contains a promotional link to a competing listing site." },
];

export const auditLog = [
  { id: "AUD-3301", actor: "Bilal Ahmed", action: "Approved partner application", target: "Coastal Catch (APP-1078)", kind: "success", at: daysAgo(0) },
  { id: "AUD-3300", actor: "Danish Qureshi", action: "Verified subscription receipt", target: "Cafe Flo (SUB-9048)", kind: "success", at: daysAgo(0) },
  { id: "AUD-3299", actor: "Hira Malik", action: "Suspended host account", target: "Saba Qamar (HST-507)", kind: "danger", at: daysAgo(3) },
  { id: "AUD-3298", actor: "Bilal Ahmed", action: "Suspended restaurant", target: "The Village (RST-112)", kind: "danger", at: daysAgo(3) },
  { id: "AUD-3297", actor: "Ayesha Siddiqui", action: "Updated subscription pricing", target: "Partner Pro annual: Rs. 50,000", kind: "orange", at: daysAgo(5) },
  { id: "AUD-3296", actor: "Danish Qureshi", action: "Rejected payment receipt", target: "Cafe Zouk (SUB-9051)", kind: "danger", at: daysAgo(6) },
  { id: "AUD-3295", actor: "Zara Iqbal", action: "Resolved customer report", target: "Fahad Iqbal (CUS-7006)", kind: "success", at: daysAgo(2) },
  { id: "AUD-3294", actor: "Hira Malik", action: "Removed flagged review", target: "Review REV-4419", kind: "orange", at: daysAgo(5) },
];

/* Platform-level totals behind the dashboard KPIs. The tables below show the
   most recent slice; these counters describe the whole platform in the
   prototype's fictional Karachi pilot. */
export const metrics = {
  restaurants: { total: 128, delta: 6.4, active: 112, pending: 9, suspended: 7 },
  partners: { total: 96, delta: 4.1 },
  customers: { total: 4318, delta: 8.7 },
  hosts: { total: 62, delta: 2.3 },
  subscriptions: { active: 96, mrr: 512000, delta: 7.2, expiring: 11 },
  reservations: { month: 1842, delta: 5.8 },
  experiences: { total: 37, delta: 12.5, seats: 684 },
  revenue: { month: 512000, ytd: 4234000 },
};

export const revenueSeries = [
  { label: "Jun", value: 262000 }, { label: "Jul", value: 318000 }, { label: "Aug", value: 356000 },
  { label: "Sep", value: 401000 }, { label: "Oct", value: 462000 }, { label: "Nov", value: 512000 },
];

export const partnerGrowthSeries = [
  { label: "Jun", value: 48 }, { label: "Jul", value: 57 }, { label: "Aug", value: 66 },
  { label: "Sep", value: 74 }, { label: "Oct", value: 85 }, { label: "Nov", value: 96 },
];

export const reservationsSeries = [
  { label: "Jun", value: 1180 }, { label: "Jul", value: 1290 }, { label: "Aug", value: 1405 },
  { label: "Sep", value: 1560 }, { label: "Oct", value: 1720 }, { label: "Nov", value: 1842 },
];

export const experienceSeries = [
  { label: "Jun", value: 14 }, { label: "Jul", value: 18 }, { label: "Aug", value: 22 },
  { label: "Sep", value: 27 }, { label: "Oct", value: 32 }, { label: "Nov", value: 37 },
];

export const planSplit = [
  { label: "Partner Pro Annual", value: 58, color: "#f97316" },
  { label: "Partner Pro Monthly", value: 38, color: "#fdba74" },
  { label: "Expired or unpaid", value: 14, color: "#e3d9d0" },
];

export const citySplit = [
  { label: "Karachi", value: 112 },
  { label: "Lahore", value: 9 },
  { label: "Islamabad", value: 5 },
  { label: "Other", value: 2 },
];

export const contentItems = [
  { id: "CON-9001", kind: "Review", target: "Kolachi Restaurant", excerpt: "Worst service ever, the waiter insulted my sister and this place is a scam. Do not go.", author: "Sana Mirza", at: daysAgo(0), status: "flagged", reason: "Abusive language toward staff", reports: 2 },
  { id: "CON-9002", kind: "Review", target: "Cafe Flo", excerpt: "Amazing brunch. Also follow my page for 50% off menus at a competing cafe.", author: "Ahsan Raza", at: daysAgo(1), status: "flagged", reason: "Promotional link to another business", reports: 1 },
  { id: "CON-9003", kind: "Photo", target: "Kababjees", excerpt: "Cover photo uploaded by the partner: dine-in area with visible alcohol bottles on the counter.", author: "Kamran Ali", at: daysAgo(2), status: "pending_review", reason: "Venue image policy check", reports: 0 },
  { id: "CON-9004", kind: "Menu item", target: "The Village", excerpt: "Section: signature karahi. Price listed as Rs. 950 while the printed menu shows Rs. 1,500.", author: "Junaid Akhtar", at: daysAgo(3), status: "flagged", reason: "Price mismatch reported by two guests", reports: 2 },
  { id: "CON-9005", kind: "Review", target: "Xander's", excerpt: "Quiet corner, strong coffee, and the staff remembered our names on the second visit.", author: "Hira Nadeem", at: daysAgo(3), status: "approved", reason: "Reviewed after an automated spam score", reports: 0 },
  { id: "CON-9006", kind: "Experience copy", target: "Brunch & Jazz Morning", excerpt: "Description promises a live quartet for every seating. The venue confirmed no band is booked.", author: "Mawra Hocane", at: daysAgo(1), status: "pending_review", reason: "Advertised content not confirmed", reports: 1 },
  { id: "CON-9007", kind: "Photo", target: "Salt & Pepper Bistro", excerpt: "Dish photo appears to be a stock image of a pizza from another chain.", author: "Mehwish Baig", at: daysAgo(4), status: "flagged", reason: "Misleading imagery", reports: 1 },
  { id: "CON-9008", kind: "Review", target: "Bar B Q Tonight", excerpt: "Food was great but the wait was 40 minutes on a Saturday. Two stars.", author: "Hamza Sheikh", at: daysAgo(5), status: "approved", reason: "Reported by the venue, kept as honest feedback", reports: 1 },
];

export const notificationItems = [
  { id: "N1", title: "4 partner applications waiting", detail: "Sajjad's Charcoal Grill, Chai Khana, Biryani Junction and 1 more", at: daysAgo(0), kind: "orange" },
  { id: "N2", title: "2 payment receipts need verification", detail: "Okra and Xander's uploaded receipts today", at: daysAgo(0), kind: "info" },
  { id: "N3", title: "Subscription expiring in 6 days", detail: "Espresso Shahbaz DHA has not renewed yet", at: daysAgo(1), kind: "warn" },
  { id: "N4", title: "High severity venue report", detail: "The Village refused an advertised deal price", at: daysAgo(0), kind: "danger" },
  { id: "N5", title: "Experience cancelled by venue", detail: "Rooftop Grill Night had 31 guests booked", at: daysAgo(3), kind: "danger" },
];

export const activityFeed = [
  { id: "ACT-1", who: "Hassan Raza", what: "published 3 menu updates at Kolachi Restaurant", at: daysAgo(0), kind: "success" },
  { id: "ACT-2", who: "Kamran Ali", what: "created the deal Free dessert with any karahi", at: daysAgo(0), kind: "orange" },
  { id: "ACT-3", who: "Ayesha Omar", what: "opened 4 seats for Seafront Sunset Tasting", at: daysAgo(1), kind: "info" },
  { id: "ACT-4", who: "Sana Tariq", what: "updated opening hours at Cafe Aylanto", at: daysAgo(1), kind: "quiet" },
  { id: "ACT-5", who: "Fawad Khan", what: "requested a second Coffee Cupping Session", at: daysAgo(2), kind: "info" },
];

export const settings = {
  platformName: "DineCircle",
  supportEmail: "support@dinecircle.app",
  currency: "PKR",
  timezone: "Asia/Karachi",
  city: "Karachi",
  autoApproveVenues: false,
  requireReceipt: true,
  emailOnNewApplication: true,
  emailOnPaymentUpload: true,
  weeklyDigest: false,
  maintenanceMode: false,
  riskFlagThreshold: 2,
};

export const seedState = () => ({
  applications,
  restaurants,
  partnerAccounts,
  subscriptions,
  customers,
  hosts,
  experiences,
  deals,
  reports,
  contentItems,
  auditLog,
  plans,
  admins,
  settings,
  notificationsSeen: false,
});
