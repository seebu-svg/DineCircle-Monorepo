#!/usr/bin/env python3
"""DineCircle website generator.

Builds the static multi-page site (listing pages, per-venue / per-experience /
per-host detail pages, legal pages) from one content model so the header,
footer and card components never drift. Run: python3 build.py
"""
from pathlib import Path
from urllib.parse import quote
import html
import os
import unicodedata
from seo import SITE_URL, SOCIAL, STORE_LINKS, enhance_page, write_crawl_files

ROOT = Path(__file__).parent
SITE_NAME = "DineCircle"
EMAIL = "hello@dinecircle.app"
PARTNER_EMAIL = "partners@dinecircle.app"
SUPPORT_EMAIL = "support@dinecircle.app"
EFFECTIVE = "7 November 2026"
LOCATION = "Karachi, Pakistan"
SUPPORT_HOURS = "Monday to Saturday, 10 AM to 7 PM PKT"
TAGLINE = "Great food. Shared moments."
# SOCIAL and STORE_LINKS are imported from seo.py, which reads them out of
# seo-config.json. One config file drives the footer social block, the
# Organization sameAs list, the store badges and the SoftwareApplication
# downloadUrl, so no two surfaces can disagree about what is live. An empty
# store value is not a broken link waiting to be filled: it renders an honest
# "Coming soon" badge and the notify-me capture instead, and setting a URL
# flips that platform's badge with no template change.

# Where lead forms post. Left empty, every form keeps its mailto fallback and
# the site stores nothing. A deploy can point it elsewhere with
# DINECIRCLE_LEAD_API without touching the templates.
LEAD_API = os.environ.get(
    "DINECIRCLE_LEAD_API", "https://dinecircle-api.onrender.com/api/public/leads"
)


def esc(value):
    return html.escape(str(value), quote=True)


def money(value):
    return f"Rs. {value:,}"


def dish(name, desc, price, img=None, tags=()):
    return {"name": name, "desc": desc, "price": price, "img": img, "tags": list(tags)}


def sec(name, *items):
    return {"name": name, "items": list(items)}


def offer(title, desc, label, kind, value, code, terms, redeem, img, venue=None):
    return {
        "title": title, "desc": desc, "label": label, "kind": kind, "value": value,
        "code": code, "terms": terms, "redeem": redeem, "img": img, "venue": venue,
    }


VENUES = [
    {
        "slug": "kolachi",
        "name": "Kolachi Restaurant",
        "tagline": "Sea-facing Pakistani dining at Do Darya",
        "about": "A Do Darya seaside institution known for grilled seafood, mutton karahi and long family tables looking out over the water. Book a table for the sunset, stay for the karahi.",
        "cuisines": ["Pakistani", "Seafood", "BBQ"],
        "area": "Do Darya, DHA Phase 8",
        "address": "Do Darya seafront, DHA Phase 8, Karachi",
        "price": "$$$",
        "verified": True,
        "featured": True,
        "cover": "venue_rooftop",
        "gallery": ["dish_steak", "venue_bar", "dish_sushi"],
        "lat": 24.8055, "lng": 67.0305,
        "open": "13:00", "close": "23:30", "closed": [],
        "amenities": ["Seafront seating", "Family sections", "Valet parking", "Wheelchair access", "Card payments"],
        "menu": [
            sec("From the Grill",
                dish("Grilled Prawns", "Jumbo prawns, lemon butter and green chutney.", 2450, "dish_steak", ["Seafood"]),
                dish("Fish Tikka", "Marinated fillets finished over charcoal.", 1890, "dish_steak", ["Seafood", "Spicy"]),
                dish("Chicken Malai Boti", "Cream-marinated boneless chicken, charcoal grilled.", 1290, "dish_steak", ["Popular"]),
                dish("Mutton Chops", "Four chops, dry rub, served with mint raita.", 2650, None, ["Chef's pick"])),
            sec("Karahi & Curries",
                dish("Mutton Karahi (Half)", "Tomato-forward karahi with ginger and green chilli.", 3450, "hero_tasting", ["Spicy"]),
                dish("Chicken Karahi (Full)", "Cooked to order in a black iron karahi.", 2790, None, ["Spicy"]),
                dish("Prawn Karahi", "Prawns simmered in a light tomato masala.", 2890, None, ["Seafood"])),
            sec("Rice & Breads",
                dish("Mutton Pulao", "Long-grain rice with slow-cooked mutton stock.", 1490),
                dish("Garlic Naan", "Tandoor naan brushed with garlic butter.", 220, None, ["Vegetarian"]),
                dish("Kachumber Salad", "Onion, tomato, cucumber, lemon.", 390, None, ["Vegan"])),
            sec("Desserts & Drinks",
                dish("Kulfi Falooda", "Traditional kulfi with vermicelli and rose syrup.", 690, "dish_dessert", ["Vegetarian"]),
                dish("Fresh Lime Soda", "Sweet or salted.", 350, None, ["Vegan"])),
        ],
        "deals": [
            offer("15% off family dinner", "15% off the total bill for family tables at dinner service.",
                  "-15%", "percent", 15, "KOLACHI15",
                  "Dine-in only, 19:00–23:00, tables of four or more, one offer per table, excludes public holidays.",
                  "Show the deal to your server before the bill is printed.", "dish_steak"),
            offer("BBQ platter for Rs. 2,999", "Shared grill platter for four: seekh kebab, chicken tikka, malai boti, naan and raita at a set price.",
                  "Rs. 2,999", "set", 2999, None,
                  "Fixed contents, no substitutions, dine-in only, available after 19:00.",
                  "Ask for the DineCircle BBQ platter when ordering.", "dish_steak"),
        ],
        "experience": "bbq-night",
    },
    {
        "slug": "kababjees",
        "name": "Kababjees",
        "tagline": "Charcoal kebabs and family grills",
        "about": "A busy Do Darya grill house built around seekh kebab, tikka and family-sized platters. Casual, loud in the best way, and open late.",
        "cuisines": ["BBQ", "Pakistani"],
        "area": "Do Darya, DHA Phase 8",
        "address": "Do Darya, DHA Phase 8, Karachi",
        "price": "$$",
        "verified": True,
        "cover": "dish_steak",
        "gallery": ["venue_interior", "dish_brunch"],
        "lat": 24.8041, "lng": 67.0281,
        "open": "16:00", "close": "23:59", "closed": [],
        "amenities": ["Outdoor seating", "Family hall", "Takeaway", "Card payments"],
        "menu": [
            sec("Kebabs",
                dish("Chicken Seekh Kebab", "Four skewers, mint chutney and onion.", 990, "dish_steak"),
                dish("Beef Seekh Kebab", "Coarse-ground beef, charred edges.", 1150, "dish_steak"),
                dish("Chicken Tikka (Half)", "Bone-in, red masala marinade.", 1090, None, ["Spicy"]),
                dish("Bihari Boti", "Thin-sliced beef in papaya marinade.", 1390)),
            sec("Platters",
                dish("Family Mixed Grill", "Kebabs, boti, tikka and naan for four.", 4590, "dish_steak", ["Spicy"]),
                dish("Kababjees Special Platter", "Chef selection for two.", 2890)),
            sec("Sides & Drinks",
                dish("Garlic Naan", "Fresh from the tandoor.", 200, None, ["Vegetarian"]),
                dish("Raita", "Yoghurt, cucumber and mint.", 250, None, ["Vegetarian"]),
                dish("Soft Drink", "Chilled bottle.", 150, None, ["Vegan"])),
        ],
        "deals": [
            offer("20% off dinner", "20% off the food bill on dinner orders for dine-in guests.",
                  "-20%", "percent", 20, "KABABJEES20",
                  "From 19:00, food only, excludes drinks and desserts, not combinable with other offers.",
                  "Quote the code to your server before ordering.", "dish_steak"),
            offer("Family BBQ combo for Rs. 3,499", "Family combo for four: two kebab platters, chicken tikka, naan, salad and soft drinks.",
                  "Rs. 3,499", "set", 3499, None,
                  "For four guests, fixed items, dine-in only.",
                  "Ask for the DineCircle family combo at the counter.", "dish_steak"),
        ],
    },
    {
        "slug": "bbq-tonight",
        "name": "Bar B Q Tonight",
        "tagline": "Clifton grill house, open late",
        "about": "A Clifton grill institution with an open charcoal floor and a menu of kebabs, tikka and karahi served late into the night.",
        "cuisines": ["BBQ", "Pakistani", "Karahi"],
        "area": "Boat Basin, Clifton",
        "address": "Boat Basin, Clifton, Karachi",
        "price": "$$",
        "verified": True,
        "cover": "venue_bar",
        "gallery": ["dish_steak", "venue_interior"],
        "lat": 24.8100, "lng": 67.0255,
        "open": "16:00", "close": "23:59", "closed": [],
        "amenities": ["Open grill floor", "Late hours", "Family cabins", "Parking"],
        "menu": [
            sec("Grill",
                dish("Chicken Malai Boti", "Creamy marinade, soft char.", 1250, "dish_steak"),
                dish("Beef Bihari Kebab", "Sliced beef, mustard and papaya.", 1450),
                dish("Mutton Seekh Kebab", "Hand-minced mutton skewers.", 1590, "dish_steak"),
                dish("Grilled Chicken (Full)", "Half or full, with chutney.", 1790)),
            sec("Karahi",
                dish("Chicken Karahi (Half)", "Tomato, ginger, green chilli.", 2190, None, ["Spicy"]),
                dish("Mutton Karahi (Half)", "Slow-cooked, bone-in.", 3290)),
            sec("Breads & Sides",
                dish("Tandoori Roti", "Whole wheat, fresh.", 90, None, ["Vegan"]),
                dish("Green Salad", "Seasonal vegetables.", 290, None, ["Vegan"]),
                dish("Mint Lemonade", "Fresh mint, lemon, soda.", 390, None, ["Vegan"])),
        ],
        "deals": [
            offer("15% off BBQ buffet", "15% off the per-person BBQ buffet for dine-in guests.",
                  "-15%", "percent", 15, "BBQT15",
                  "Buffet timings 19:30–23:00, per person, excludes drinks, dine-in only.",
                  "Mention the code at reception before the buffet starts.", "dish_steak"),
            offer("Buy 2 mains, get 1 free", "Order two main courses and the lowest-priced third main is free.",
                  "3 for 2", "multibuy", 0, None,
                  "Minimum two paying guests, free item is the lowest-priced main, dine-in only.",
                  "Tell your server the deal is being applied when ordering.", "dish_steak"),
        ],
    },
    {
        "slug": "cafe-aylanto",
        "name": "Cafe Aylanto",
        "tagline": "Courtyard dining in Clifton",
        "about": "A courtyard restaurant in Clifton serving Mediterranean and Lebanese plates, with a long menu and a terrace built for slow dinners.",
        "cuisines": ["Mediterranean", "Lebanese", "Continental"],
        "area": "Clifton",
        "address": "Clifton Block 5, Karachi",
        "price": "$$$",
        "verified": True,
        "featured": True,
        "cover": "venue_bar",
        "gallery": ["dish_pasta", "dish_dessert", "venue_interior"],
        "lat": 24.8160, "lng": 67.0280,
        "open": "12:00", "close": "23:00", "closed": [],
        "amenities": ["Courtyard seating", "Terrace", "Reservations recommended", "Card payments"],
        "menu": [
            sec("Mezze",
                dish("Hummus Beiruti", "Chickpeas, tahini, chilli and olive oil.", 890, None, ["Vegetarian", "Vegan"]),
                dish("Falafel Plate", "Six falafel, pickles, tahini sauce.", 950, None, ["Vegan"]),
                dish("Moutabel", "Smoked aubergine with yoghurt and mint.", 920, None, ["Vegetarian"]),
                dish("Fattoush", "Sumac, crisp pita, seasonal leaves.", 850, None, ["Vegetarian"])),
            sec("Mains",
                dish("Grilled Chicken Breast", "Lemon-herb marinade, seasonal vegetables.", 2350),
                dish("Lamb Kofta", "Charcoal-grilled, served with rice.", 2890, "dish_steak"),
                dish("Sea Bass Fillet", "Pan-seared, salsa verde.", 3250, "dish_sushi", ["Seafood"])),
            sec("Pasta & Risotto",
                dish("Penne Arrabbiata", "Tomato, garlic, chilli.", 1750, "dish_pasta", ["Vegetarian", "Spicy"]),
                dish("Mushroom Risotto", "Arborio rice, parmesan, truffle oil.", 1950, "dish_pasta", ["Vegetarian"])),
            sec("Desserts",
                dish("Baklava", "Pistachio, honey syrup.", 750, "dish_dessert", ["Vegetarian"]),
                dish("Chocolate Fondant", "Warm centre, vanilla ice cream.", 890, "dish_dessert", ["Vegetarian"])),
        ],
        "deals": [
            offer("20% off lunch", "20% off the food bill at weekday lunch service.",
                  "-20%", "percent", 20, "AYLANTO20",
                  "Monday–Friday 12:30–16:00, food only, not valid on public holidays.",
                  "Show the deal to your server before ordering.", "dish_pasta"),
            offer("Couple dinner for Rs. 4,999", "Three courses for two: shared mezze, two mains and one dessert at a set price.",
                  "Rs. 4,999", "set", 4999, None,
                  "For two guests, fixed menu, table booking recommended.",
                  "Ask for the DineCircle couple dinner when reserving.", "dish_pasta"),
        ],
        "experience": "meet-new-people",
    },
    {
        "slug": "okra",
        "name": "Okra",
        "tagline": "Mediterranean plates in DHA",
        "about": "A DHA dining room with a Mediterranean-leaning kitchen, a wood-fired oven and a quiet terrace away from the boulevard.",
        "cuisines": ["Mediterranean", "Continental", "Italian"],
        "area": "DHA Phase 8",
        "address": "DHA Phase 8, Karachi",
        "price": "$$$",
        "verified": True,
        "cover": "hero_tasting",
        "gallery": ["dish_pasta", "venue_rooftop", "dish_tacos"],
        "lat": 24.8010, "lng": 67.0740,
        "open": "12:30", "close": "23:30", "closed": ["mon"],
        "amenities": ["Terrace", "Wood-fired oven", "Private dining", "Parking"],
        "menu": [
            sec("Starters",
                dish("Burrata & Tomato", "Fresh burrata, heirloom tomato, basil oil.", 1650, None, ["Vegetarian"]),
                dish("Calamari Fritti", "Light batter, lemon aioli.", 1590, "dish_sushi", ["Seafood"]),
                dish("Soup of the Day", "Ask the kitchen.", 690, None, ["Vegetarian"])),
            sec("Wood-Fired Pizza",
                dish("Margherita", "San Marzano tomato, fior di latte, basil.", 1550, "dish_pasta", ["Vegetarian"]),
                dish("Spicy Salami", "Salami, chilli, mozzarella.", 1850, "dish_pasta", ["Spicy"]),
                dish("Truffle Mushroom", "Mushroom, truffle cream, parmesan.", 1950, "dish_pasta", ["Vegetarian"])),
            sec("Mains",
                dish("Grilled Lamb Chops", "Four chops, rosemary jus.", 3890, "venue_interior"),
                dish("Pan-Seared Salmon", "Lemon butter, seasonal greens.", 3250, "dish_sushi", ["Seafood"]),
                dish("Wild Mushroom Pasta", "Tagliatelle, cream, parmesan.", 2150, "dish_pasta", ["Vegetarian"])),
            sec("Desserts",
                dish("Tiramisu", "Espresso-soaked sponge, mascarpone.", 890, "dish_dessert", ["Vegetarian"]),
                dish("Panna Cotta", "Vanilla, berry compote.", 790, "dish_dessert", ["Vegetarian"])),
        ],
        "deals": [
            offer("15% off selected main courses", "15% off the marked mains on the DineCircle list.",
                  "-15%", "percent", 15, "OKRA15",
                  "Applies to marked mains only, food only, dine-in.",
                  "Point to this deal when ordering your mains.", "dish_pasta"),
            offer("Complimentary dessert with 2 mains", "One dessert on the house for every two mains ordered.",
                  "Free dessert", "multibuy", 0, None,
                  "One dessert per table, minimum two mains, dine-in only.",
                  "Ask your server for the complimentary dessert.", "dish_dessert"),
        ],
    },
    {
        "slug": "xanders",
        "name": "Xander's",
        "tagline": "All-day café in Clifton",
        "about": "A Clifton café doing all-day breakfast, sandwiches and serious coffee. Popular for long weekend brunches and laptop mornings.",
        "cuisines": ["Café", "Continental", "Brunch"],
        "area": "Clifton",
        "address": "Clifton Block 4, Karachi",
        "price": "$$",
        "verified": True,
        "featured": True,
        "cover": "dish_brunch",
        "gallery": ["venue_interior", "dish_dessert"],
        "lat": 24.8122, "lng": 67.0332,
        "open": "09:00", "close": "23:00", "closed": [],
        "amenities": ["All-day breakfast", "Wi-Fi", "Outdoor seating", "Card payments"],
        "menu": [
            sec("All-Day Breakfast",
                dish("Big Breakfast", "Eggs, sausage, toast, grilled tomato, hash brown.", 1690, "dish_brunch", ["Vegetarian"]),
                dish("Eggs Benedict", "Poached eggs, hollandaise, English muffin.", 1590, "dish_brunch"),
                dish("French Toast", "Brioche, maple syrup, berries.", 1290, "dish_brunch", ["Vegetarian"]),
                dish("Shakshuka", "Eggs baked in spiced tomato.", 1390, "dish_brunch", ["Vegetarian", "Spicy"])),
            sec("Sandwiches & Salads",
                dish("Club Sandwich", "Triple decker with fries.", 1450, "dish_brunch"),
                dish("Chicken Caesar", "Cos lettuce, parmesan, croutons.", 1390, None, ["Spicy"]),
                dish("Grilled Halloumi Wrap", "Halloumi, hummus, roasted vegetables.", 1290, None, ["Vegetarian"])),
            sec("Coffee & Cake",
                dish("Cappuccino", "Double shot, steamed milk.", 590, None, ["Vegetarian"]),
                dish("Flat White", "Stronger, less foam.", 590, "venue_bar", ["Vegetarian"]),
                dish("Carrot Cake", "Cream cheese frosting.", 750, "dish_dessert", ["Vegetarian"]),
                dish("Chocolate Brownie", "Warm, with ice cream.", 790, "dish_dessert", ["Vegetarian"])),
        ],
        "deals": [
            offer("Buy 1 pizza, get 1 at 50% off", "Order any pizza and the second one of equal or lower value is half price.",
                  "2nd 50% off", "multibuy", 0, None,
                  "Dine-in only, second pizza must be equal or lower value, excludes delivery.",
                  "Tell your server before the order is fired.", "dish_pasta"),
            offer("Breakfast combo for Rs. 1,499", "Breakfast for two: eggs any style, toast, fruit and two coffees at a set price.",
                  "Rs. 1,499", "set", 1499, None,
                  "Served 08:00–12:00, for two guests, fixed items.",
                  "Ask for the DineCircle breakfast combo on arrival.", "dish_brunch"),
        ],
        "experience": "sunday-brunch",
    },
    {
        "slug": "espresso-shahbaz",
        "name": "Espresso Shahbaz DHA",
        "tagline": "Neighbourhood espresso bar in DHA Phase 6",
        "about": "A compact DHA Phase 6 espresso bar with pastries, sandwiches and a steady laptop crowd. The kind of place you return to twice in a day.",
        "cuisines": ["Café", "Coffee", "Desserts"],
        "area": "DHA Phase 6",
        "address": "DHA Phase 6, Karachi",
        "price": "$$",
        "verified": True,
        "cover": "dish_dessert",
        "gallery": ["venue_bar", "dish_brunch"],
        "lat": 24.7980, "lng": 67.0610,
        "open": "08:00", "close": "23:00", "closed": [],
        "amenities": ["Wi-Fi", "Laptop-friendly", "Takeaway", "Card payments"],
        "menu": [
            sec("Espresso Bar",
                dish("Espresso", "Single or double, house blend.", 380, None, ["Vegan"]),
                dish("Flat White", "Double shot, silky milk.", 560, "venue_bar", ["Vegetarian"]),
                dish("Cortado", "Equal parts espresso and milk.", 520, None, ["Vegetarian"]),
                dish("Iced Latte", "Double shot over ice.", 620, None, ["Vegetarian"])),
            sec("Bakery",
                dish("Butter Croissant", "Baked in-house each morning.", 450, "dish_dessert", ["Vegetarian"]),
                dish("Almond Danish", "Frangipane, flaked almonds.", 520, "dish_dessert", ["Vegetarian"]),
                dish("Chocolate Cookie", "Dark chocolate chunks.", 350, "dish_dessert", ["Vegetarian"])),
            sec("Sandwiches",
                dish("Grilled Cheese", "Sourdough, cheddar, tomato.", 890, None, ["Vegetarian"]),
                dish("Chicken Panini", "Pesto, mozzarella, chicken.", 1150, "dish_brunch"),
                dish("Avocado Toast", "Sourdough, chilli flakes, lime.", 950, "dish_brunch", ["Vegan"])),
        ],
        "deals": [
            offer("Buy 1 coffee, get 1 free", "Two espresso drinks for the price of one, same size.",
                  "2 for 1", "multibuy", 0, None,
                  "Same size only, dine-in, once per visit.",
                  "Order both drinks together and mention this deal.", "dish_brunch"),
            offer("Coffee + sandwich for Rs. 999", "Any espresso drink with a sandwich from the counter menu at a set price.",
                  "Rs. 999", "set", 999, None,
                  "Weekdays 11:00–17:00, selected sandwiches only.",
                  "Show this deal at the counter when ordering.", "dish_brunch"),
        ],
        "experience": "coffee-lovers",
    },
    {
        "slug": "cafe-flo",
        "name": "Cafe Flo",
        "tagline": "French-leaning café in Clifton",
        "about": "A Clifton café with a French-leaning pastry counter, crepes and a garden-style room that stays quiet through the afternoon.",
        "cuisines": ["Café", "French", "Desserts"],
        "area": "Clifton",
        "address": "Clifton Block 6, Karachi",
        "price": "$$",
        "verified": True,
        "cover": "venue_interior",
        "gallery": ["dish_dessert", "dish_brunch"],
        "lat": 24.8145, "lng": 67.0265,
        "open": "10:00", "close": "23:30", "closed": [],
        "amenities": ["Garden seating", "Pastry counter", "Wi-Fi", "Card payments"],
        "menu": [
            sec("Crepes & Waffles",
                dish("Nutella Crepe", "Thin crepe, hazelnut spread, banana.", 990, "dish_dessert", ["Vegetarian"]),
                dish("Lemon Sugar Crepe", "Classic, with a lemon wedge.", 790, "dish_dessert", ["Vegetarian"]),
                dish("Belgian Waffle", "Maple syrup, butter.", 950, "dish_dessert", ["Vegetarian"])),
            sec("Savoury",
                dish("Croque Monsieur", "Ham, gruyere, bechamel.", 1450, "dish_brunch"),
                dish("Quiche Lorraine", "Bacon, cream, gruyere.", 1290, "dish_brunch"),
                dish("Cheese Omelette", "Three eggs, herbs, toast.", 1190, "dish_brunch", ["Vegetarian"])),
            sec("Coffee & Chocolate",
                dish("Hot Chocolate", "Dark chocolate, whipped cream.", 690, "dish_dessert", ["Vegetarian"]),
                dish("Cafe Latte", "Double shot, steamed milk.", 590, None, ["Vegetarian"]),
                dish("Cappuccino", "Classic ratio.", 590, None, ["Vegetarian"])),
        ],
        "deals": [
            offer("20% off weekday lunch", "20% off the food bill at weekday lunch service.",
                  "-20%", "percent", 20, "FLO20",
                  "Monday–Friday 12:00–16:00, food only, dine-in.",
                  "Show the deal to your server before ordering.", "dish_brunch"),
            offer("Dinner for two for Rs. 5,999", "Two starters, two mains and one dessert for two at a set price.",
                  "Rs. 5,999", "set", 5999, None,
                  "For two guests, after 19:00, reservation recommended.",
                  "Ask for the DineCircle dinner for two when reserving.", "dish_dessert"),
        ],
    },
    {
        "slug": "butlers",
        "name": "Butlers Chocolate Café",
        "tagline": "Chocolate café on Zamzama",
        "about": "A Zamzama chocolate café with a dessert-heavy menu, fondues and a quiet upstairs room. Come for the cake, stay for the hot chocolate.",
        "cuisines": ["Café", "Chocolate", "Desserts"],
        "area": "Zamzama",
        "address": "Zamzama Boulevard, Karachi",
        "price": "$$",
        "verified": False,
        "cover": "dish_dessert",
        "gallery": ["dish_brunch", "venue_bar"],
        "lat": 24.8165, "lng": 67.0405,
        "open": "11:00", "close": "23:30", "closed": [],
        "amenities": ["Dessert menu", "Upstairs seating", "Takeaway", "Card payments"],
        "menu": [
            sec("Chocolate",
                dish("Chocolate Fondue for Two", "Warm chocolate, fruit and marshmallows.", 1890, "dish_dessert", ["Vegetarian"]),
                dish("Chocolate Lava Cake", "Molten centre, vanilla ice cream.", 990, "dish_dessert", ["Vegetarian"]),
                dish("Truffle Box (6)", "Assorted dark and milk truffles.", 1250, "dish_dessert", ["Vegetarian"])),
            sec("Cakes & Slices",
                dish("Chocolate Fudge Cake", "Three layers, ganache.", 890, "dish_dessert", ["Vegetarian"]),
                dish("Cheesecake", "Baked vanilla cheesecake.", 850, "dish_dessert", ["Vegetarian"]),
                dish("Carrot Cake", "Walnut, cream cheese.", 790, "dish_dessert", ["Vegetarian"])),
            sec("Drinks",
                dish("Signature Hot Chocolate", "Thick, dark, whipped cream.", 790, None, ["Vegetarian"]),
                dish("Iced Mocha", "Espresso, chocolate, milk.", 750, None, ["Vegetarian"]),
                dish("Americano", "Long black.", 490, None, ["Vegan"])),
        ],
        "deals": [
            offer("Buy 1 hot chocolate, get 1 free", "Two signature hot chocolates for the price of one, same size.",
                  "2 for 1", "multibuy", 0, None,
                  "Same size only, dine-in, once per visit.",
                  "Mention this deal at the counter when ordering.", "dish_dessert"),
            offer("Cake slice + hot drink for Rs. 999", "Any selected cake slice with a regular hot drink at a set price.",
                  "Rs. 999", "set", 999, None,
                  "Selected cakes only, dine-in, weekdays.",
                  "Show this deal when placing your order.", "dish_dessert"),
        ],
    },
    {
        "slug": "esquires",
        "name": "Esquires Coffee",
        "tagline": "Coffee house on Zamzama",
        "about": "A Zamzama coffee house with a broad drinks menu, breakfast plates and plenty of table space for groups.",
        "cuisines": ["Café", "Coffee", "Breakfast"],
        "area": "Zamzama",
        "address": "Zamzama Boulevard, Karachi",
        "price": "$$",
        "verified": False,
        "cover": "venue_bar",
        "gallery": ["dish_brunch", "dish_dessert"],
        "lat": 24.8170, "lng": 67.0420,
        "open": "08:30", "close": "23:00", "closed": [],
        "amenities": ["Wi-Fi", "Breakfast", "Group seating", "Card payments"],
        "menu": [
            sec("Breakfast",
                dish("Full Breakfast", "Eggs, sausage, beans, toast.", 1590, "dish_brunch"),
                dish("Omelette", "Three eggs, cheese, herbs, toast.", 1290, "dish_brunch", ["Vegetarian"]),
                dish("Pancake Stack", "Three pancakes, maple syrup.", 1190, "dish_brunch", ["Vegetarian"])),
            sec("Coffee",
                dish("Americano", "Long black, house blend.", 480, None, ["Vegan"]),
                dish("Cappuccino", "Classic ratio.", 570, None, ["Vegetarian"]),
                dish("Mocha", "Espresso, chocolate, milk.", 650, None, ["Vegetarian"]),
                dish("Cold Brew", "Slow-steeped, served over ice.", 690, None, ["Vegan"])),
            sec("Light Meals",
                dish("Chicken Panini", "Grilled, with a side salad.", 1250, "dish_brunch"),
                dish("Caesar Salad", "Cos, parmesan, croutons.", 1290, None, ["Spicy"]),
                dish("Soup & Toast", "Soup of the day with sourdough.", 890, None, ["Vegetarian"])),
        ],
        "deals": [
            offer("20% off breakfast", "20% off any breakfast plate ordered before 11:30.",
                  "-20%", "percent", 20, "ESQ20",
                  "Until 11:30, food only, dine-in.",
                  "Quote the code at the counter before ordering.", "dish_brunch"),
            offer("Coffee + dessert for Rs. 899", "Any regular coffee with a selected dessert at a set price.",
                  "Rs. 899", "set", 899, None,
                  "Selected desserts only, dine-in.",
                  "Ask for the DineCircle coffee and dessert combo.", "dish_dessert"),
        ],
    },
    {
        "slug": "cafe-zouk",
        "name": "Café Zouk",
        "tagline": "Wood-fired pizza and pasta on Zamzama",
        "about": "A Zamzama café built around a wood-fired oven: thin-crust pizza, pasta and a courtyard that fills up after sunset.",
        "cuisines": ["Italian", "Pizza", "Café"],
        "area": "Zamzama, DHA Phase 5",
        "address": "Zamzama Boulevard, DHA Phase 5, Karachi",
        "price": "$$",
        "verified": False,
        "featured": True,
        "cover": "dish_pasta",
        "gallery": ["venue_interior", "dish_dessert", "venue_bar"],
        "lat": 24.8145, "lng": 67.0433,
        "open": "12:00", "close": "23:30", "closed": [],
        "amenities": ["Courtyard seating", "Family friendly", "Takeaway", "Card payments"],
        "menu": [
            sec("Starters",
                dish("Bruschetta", "Grilled sourdough, tomato, basil, olive oil.", 750, None, ["Vegetarian"]),
                dish("Garlic Bread with Cheese", "Mozzarella, garlic butter, parsley.", 650, None, ["Vegetarian"]),
                dish("Soup of the Day", "Ask the counter for today's soup.", 690)),
            sec("Wood-Fired Pizza",
                dish("Margherita", "San Marzano tomato, mozzarella, basil.", 1450, "dish_pasta", ["Vegetarian"]),
                dish("Chicken Tikka Pizza", "Tikka chunks, onion, green chilli, mozzarella.", 1950, "dish_pasta", ["Spicy"]),
                dish("Pepperoni", "Beef pepperoni, tomato, mozzarella.", 1850, "dish_pasta"),
                dish("Four Cheese", "Mozzarella, cheddar, parmesan, blue cheese.", 2150, "dish_pasta", ["Vegetarian"])),
            sec("Pasta",
                dish("Chicken Alfredo", "Fettuccine, cream, parmesan, grilled chicken.", 1650, "dish_pasta"),
                dish("Penne Arrabbiata", "Tomato, garlic, chilli, olive oil.", 1450, "dish_pasta", ["Vegetarian", "Spicy"]),
                dish("Chicken Lasagna", "Layered pasta, chicken ragu, béchamel.", 1890, "dish_pasta")),
            sec("Desserts & Drinks",
                dish("Tiramisu", "Espresso-soaked sponge, mascarpone.", 750, "dish_dessert", ["Vegetarian"]),
                dish("Chocolate Lava Cake", "Warm centre, vanilla ice cream.", 690, "dish_dessert", ["Vegetarian"]),
                dish("Fresh Lime Soda", "Sweet or salted.", 350, None, ["Vegan"])),
        ],
        "deals": [
            offer("15% off pasta and pizza", "15% off any wood-fired pizza or pasta dish, dine-in.",
                  "-15%", "percent", 15, "ZOUK15",
                  "Dine-in only, food only, not combinable with the lunch combo.",
                  "Quote the code to your server before ordering.", "dish_pasta"),
            offer("Lunch combo for Rs. 1,299", "One pasta or pizza with a soft drink at a set lunch price.",
                  "Rs. 1,299", "set", 1299, None,
                  "Monday–Friday 12:00–16:00, selected dishes only.",
                  "Ask for the DineCircle lunch combo when ordering.", "dish_pasta"),
        ],
        "experience": "pizza-night",
    },
]

HOSTS = [
    {
        "slug": "food-creator", "name": "Food Creator", "handle": "demo.foodcreator",
        "role": "Food creator & grill-table host", "specialty": "BBQ nights & grill tables",
        "portrait": "portrait_1", "city": "Karachi", "since": "2026",
        "bio": "Hosts shared grill tables around Do Darya for people who plan their week around food. Expect big platters, quick introductions and a table that stays long after dessert.",
        "interests": ["Charcoal grills", "Seafood", "Family-style sharing"],
    },
    {
        "slug": "lifestyle-creator", "name": "Lifestyle Creator", "handle": "demo.lifestylecreator",
        "role": "Lifestyle creator & brunch host", "specialty": "Brunches & café culture",
        "portrait": "portrait_2", "city": "Karachi", "since": "2026",
        "bio": "Hosts slow weekend brunches and café afternoons, with easy introductions before the food lands and open seating after it. Coffee is non-negotiable.",
        "interests": ["Brunch", "Specialty coffee", "Weekend tables"],
    },
    {
        "slug": "community-host", "name": "Community Host", "handle": "demo.communityhost",
        "role": "Community host & dinner organiser", "specialty": "Dinners for meeting new people",
        "portrait": "portrait_3", "city": "Karachi", "since": "2026",
        "bio": "Hosts dinners designed for meeting new people: one table, a set menu and a host who keeps the conversation moving. No small talk required.",
        "interests": ["Meeting new people", "Set menus", "Courtyard dinners"],
    },
    {
        "slug": "coffee-enthusiast", "name": "Coffee Enthusiast", "handle": "demo.coffeeenthusiast",
        "role": "Coffee host & tasting guide", "specialty": "Coffee meetups & tastings",
        "portrait": "portrait_4", "city": "Karachi", "since": "2026",
        "bio": "Hosts coffee meetups for people who care where the beans come from. No prior knowledge needed, just curiosity and a willingness to try something new.",
        "interests": ["Espresso", "Local roasters", "Bakery pairings"],
    },
    {
        "slug": "social-dining-host", "name": "Social Dining Host", "handle": "demo.socialdininghost",
        "role": "Social dining host & group organiser", "specialty": "Group pizza nights",
        "portrait": "portrait_5", "city": "Karachi", "since": "2026",
        "bio": "Hosts group pizza nights built around sharing, with a couple of ice-breakers before the food arrives and a courtyard table that makes it easy to talk.",
        "interests": ["Wood-fired pizza", "Group dinners", "Courtyard nights"],
    },
]

EXPERIENCES = [
    {
        "slug": "bbq-night", "title": "BBQ Night with Foodies",
        "tagline": "Shared grill platters and a table full of strangers",
        "desc": "A hosted BBQ dinner at Do Darya for people who plan their week around food. A shared grill table, plenty of introductions, then dinner. Come alone or bring a friend. The table does the rest.",
        "venue": "kolachi", "host": "food-creator",
        "offset": 3, "hour": 20, "minute": 0, "duration": 150,
        "seats": 10, "booked": 3, "price": 2500, "type": "dinner", "menu_style": "Sharing platters",
        "included": ["BBQ platter", "Naan", "Drinks", "Shared dining table", "Group meetup"],
        "tags": ["BBQ", "Meetup", "Group"], "cover": "dish_steak",
        "note": "Meet at the seafront deck entrance 10 minutes early.",
    },
    {
        "slug": "meet-new-people", "title": "Meet New People Dinner",
        "tagline": "One table, eight strangers, no awkward silences",
        "desc": "A hosted dinner built for meeting new people: a selected main, a drink and dessert, with the host keeping the conversation moving. The courtyard setting does most of the work.",
        "venue": "cafe-aylanto", "host": "community-host",
        "offset": 5, "hour": 20, "minute": 0, "duration": 150,
        "seats": 8, "booked": 2, "price": 3500, "type": "dinner", "menu_style": "Set menu",
        "included": ["Selected main course", "Drink", "Dessert", "Hosted group conversation"],
        "tags": ["Meetup", "Social"], "cover": "dish_sushi",
        "note": "Courtyard tables are weather-dependent; indoor seating is the fallback.",
    },
    {
        "slug": "sunday-brunch", "title": "Sunday Brunch & Connect",
        "tagline": "Brunch, coffee and easy introductions",
        "desc": "A hosted Sunday brunch with quick introductions before the food lands and open seating after it. Built for a slow morning and a few new names.",
        "venue": "xanders", "host": "lifestyle-creator",
        "offset": 2, "hour": 11, "minute": 0, "duration": 120,
        "seats": 8, "booked": 4, "price": 1800, "type": "brunch", "menu_style": "Set menu",
        "included": ["One brunch main", "Coffee or juice", "Introductions", "Social networking"],
        "tags": ["Brunch", "Meetup"], "cover": "dish_brunch",
        "note": "Table is held for 15 minutes; message the host if you are late.",
    },
    {
        "slug": "coffee-lovers", "title": "Coffee Lovers Meetup",
        "tagline": "One good cup and a lot of coffee talk",
        "desc": "A hosted coffee meetup for people who care where the beans come from. One specialty coffee, dessert, then an open conversation about what everyone is drinking.",
        "venue": "espresso-shahbaz", "host": "coffee-enthusiast",
        "offset": 7, "hour": 17, "minute": 0, "duration": 90,
        "seats": 12, "booked": 5, "price": 1200, "type": "workshop", "menu_style": "Tasting",
        "included": ["One specialty coffee", "Dessert", "Coffee discussions", "Casual networking"],
        "tags": ["Coffee", "Meetup"], "cover": "dish_dessert",
        "note": "No prior coffee knowledge needed.",
    },
    {
        "slug": "pizza-night", "title": "Pizza & Friends Night",
        "tagline": "Shared pizza, pasta and a table that talks",
        "desc": "A hosted pizza night built for groups: shared pizzas and pasta, soft drinks, and a couple of ice-breakers from the host before the food arrives.",
        "venue": "cafe-zouk", "host": "social-dining-host",
        "offset": 4, "hour": 20, "minute": 0, "duration": 120,
        "seats": 10, "booked": 4, "price": 1999, "type": "dinner", "menu_style": "Sharing platters",
        "included": ["Shared pizza", "Pasta", "Soft drink", "Interactive group activities"],
        "tags": ["Pizza", "Meetup", "Group"], "cover": "dish_pasta",
        "note": "Courtyard tables are held for 15 minutes after the start time.",
    },
]

VENUE_BY_SLUG = {v["slug"]: v for v in VENUES}
HOST_BY_SLUG = {h["slug"]: h for h in HOSTS}
EXP_BY_SLUG = {e["slug"]: e for e in EXPERIENCES}

# Attach venue + host objects to each experience and count hosted experiences.
for _e in EXPERIENCES:
    _e["venue_obj"] = VENUE_BY_SLUG[_e["venue"]]
    _e["host_obj"] = HOST_BY_SLUG[_e["host"]]

for _h in HOSTS:
    _h["experiences"] = [e for e in EXPERIENCES if e["host"] == _h["slug"]]

# Every deal knows its venue so the deals page can filter and link back.
ALL_DEALS = []
for _v in VENUES:
    for _d in _v["deals"]:
        _d["venue"] = _v["slug"]
        ALL_DEALS.append(_d)

CUISINES = ["Pakistani", "BBQ", "Seafood", "Café", "Italian", "Mediterranean", "Desserts", "Brunch", "Coffee", "French", "Breakfast", "Chocolate", "Lebanese", "Karahi", "Pizza", "Continental"]


def cuisines_for_filter(venue):
    """Lowercase cuisine tokens used by the filter chips."""
    return [c.lower().replace("é", "e") for c in venue["cuisines"]]


def venue_search_blob(venue):
    parts = [venue["name"], venue["tagline"], venue["area"], " ".join(venue["cuisines"])]
    parts += [item["name"] for section in venue["menu"] for item in section["items"]]
    blob = " ".join(parts).lower()
    # Fold accents so "cafe" matches "café" in client-side search.
    return "".join(c for c in unicodedata.normalize("NFKD", blob) if not unicodedata.combining(c))

# ---------------------------------------------------------------------------
# Shared copy and figures
# ---------------------------------------------------------------------------

# One FAQ source. Pages select by audience so the same answer never drifts
# between the homepage, the guide and the legal footers, and so the FAQPage
# structured data can be read back out of the HTML the page actually renders.
FAQS = [
    ("diner", "Is DineCircle free?",
     "Yes. Browsing, booking tables and joining dining experiences are free for diners. DineCircle takes no booking commission. You pay the restaurant for your food and drinks."),
    ("diner", "Do I need the app to book a table?",
     "Table bookings and experience seats happen in the DineCircle app. This website is for discovery: menus, deals, venue details and host profiles. Download App shows where the app is available today."),
    ("diner", "How do deals work?",
     "Find an offer, show it to your server before ordering, and the venue applies it to the bill. Some offers need a code; others just need you to ask. Each deal lists its own terms."),
    ("diner", "What does joining an experience cost?",
     "Joining is free. Each experience shows an estimated dining cost per person, which you pay directly to the venue on the day. There is no online checkout and no DineCircle fee."),
    ("both", "Are the menus and prices accurate?",
     "Menus, prices and opening hours are supplied by each venue and can change with the season. This site shows preview content for the Karachi pilot. Confirm details with the restaurant before you order."),
    ("both", "Which cities do you cover?",
     "Karachi is live. Lahore and Islamabad are next, with the same model: free for diners, subscription-based for partners and zero booking commission."),
    ("partner", "What does a partnership cost?",
     "PKR 5,000 per month or PKR 50,000 per year, covering every venue feature: menu, QR menu, deals, reservations, experiences and reviews. There is no per-booking charge on top."),
    ("partner", "Do you take commission on bookings?",
     "No. DineCircle charges a flat subscription and never a share of your covers or bills. You keep the reservation details and settle nothing with us per booking."),
    ("partner", "How does activation work?",
     "After your application we verify the venue, send the invoice, and activate once payment arrives by bank transfer, JazzCash or Easypaisa. A person does this, so allow one working day for each step."),
    ("partner", "Do we need a payment gateway?",
     "No. DineCircle does not take card details and does not route payments. Guests pay you directly at the table, so there is no gateway, reconciliation or payout setup on your side."),
    ("host", "How do I become a host?",
     "Create a DineCircle account, open account settings and switch to a Professional account. That unlocks Host Studio in the app, where you plan and publish your experiences."),
    ("host", "Does hosting cost anything?",
     "No. Host accounts are free, there is no listing fee and no commission. You agree the menu and format with the venue, and guests settle their own meals at the table."),
]


def faq_html(kinds, limit=None):
    wanted = set(kinds)
    picked = [row for row in FAQS if row[0] in wanted]
    if limit:
        picked = picked[:limit]
    return "".join(
        f'''<details class="faq-item">
            <summary>{esc(q)}<span class="faq-icon" aria-hidden="true"></span></summary>
            <p>{esc(a)}</p>
          </details>'''
        for _, q, a in picked
    )


def figures():
    """Derived site counts, so a figure never goes stale when data changes."""
    return {
        "venues": len(VENUES),
        "dishes": sum(len(block["items"]) for v in VENUES for block in v["menu"]),
        "offers": len(ALL_DEALS),
        "experiences": len(EXPERIENCES),
        "hosts": len(HOSTS),
    }


# ---------------------------------------------------------------------------
# Shared components
# ---------------------------------------------------------------------------

ICONS = {
    "pin": '<path d="M12 21s7-5.1 7-11a7 7 0 1 0-14 0c0 5.9 7 11 7 11Z" fill="none" stroke="currentColor" stroke-width="1.7"/><circle cx="12" cy="10" r="2.5" fill="none" stroke="currentColor" stroke-width="1.7"/>',
    "search": '<circle cx="11" cy="11" r="6.5" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="m16 16 4.5 4.5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>',
    "chevron": '<path d="m7 10 5 5 5-5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>',
    "arrow": '<path d="M4.5 12h14m-5.5-5.5L18.5 12 13 17.5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>',
    "back": '<path d="M19.5 12h-14M11 6.5 5.5 12 11 17.5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>',
    "clock": '<circle cx="12" cy="12" r="8" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M12 7.5V12l3 2" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>',
    "users": '<path d="M15.5 20v-1.4a4.1 4.1 0 0 0-4.1-4.1H7.6A4.1 4.1 0 0 0 3.5 18.6V20" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/><circle cx="9.5" cy="7.5" r="3" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M16.5 4.7a3 3 0 0 1 0 5.6M20.5 20v-1.4a4.1 4.1 0 0 0-2.8-3.9" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>',
    "check": '<path d="m5 12.5 4.3 4.3L19 7" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    "verified": '<path d="M12 3.2 19 6v5.1c0 4.4-2.9 7.9-7 9.7-4.1-1.8-7-5.3-7-9.7V6l7-2.8Z" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="m8.8 12.1 2.1 2.1 4.3-4.4" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>',
    "calendar": '<rect x="4" y="5.5" width="16" height="14.5" rx="2.5" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M8 3.5v3.5M16 3.5v3.5M4 10h16" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>',
    "close": '<path d="m6 6 12 12M18 6 6 18" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>',
    "mail": '<rect x="3.5" y="5.5" width="17" height="13" rx="2.5" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="m4.5 7 7.5 5.5L19.5 7" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>',
    "spark": '<path d="M12 3.5 13.6 9l5.4 1.6-5.4 1.6L12 17.7l-1.6-5.5L5 10.6 10.4 9 12 3.5Z" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/>',
    "download": '<path d="M12 3.5v10.5m0 0 4-4m-4 4-4-4" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/><path d="M4.5 15.5v3A2.5 2.5 0 0 0 7 21h10a2.5 2.5 0 0 0 2.5-2.5v-3" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>',
    "device": '<rect x="6.5" y="2.5" width="11" height="19" rx="2.8" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M10.5 18.4h3" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>',
    "quote": '<path d="M9.5 6.5c-3 1.3-4.8 3.9-4.8 7.2 0 2.4 1.3 3.8 3.3 3.8 1.8 0 3.1-1.3 3.1-3 0-1.7-1.2-2.9-2.8-2.9-.3 0-.6 0-.8.1.3-1.4 1.3-2.6 2.9-3.5l-.9-1.7Zm8.6 0c-3 1.3-4.8 3.9-4.8 7.2 0 2.4 1.3 3.8 3.3 3.8 1.8 0 3.1-1.3 3.1-3 0-1.7-1.2-2.9-2.8-2.9-.3 0-.6 0-.8.1.3-1.4 1.3-2.6 2.9-3.5l-.9-1.7Z" fill="currentColor"/>',
    "book": '<path d="M4 5.5A2.5 2.5 0 0 1 6.5 3H19v16.5H6.5A2.5 2.5 0 0 0 4 22V5.5Z" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H19" fill="none" stroke="currentColor" stroke-width="1.7"/>',
    "instagram": '<rect x="3.5" y="3.5" width="17" height="17" rx="5" fill="none" stroke="currentColor" stroke-width="1.7"/><circle cx="12" cy="12" r="4" fill="none" stroke="currentColor" stroke-width="1.7"/><circle cx="17.2" cy="6.8" r="1.1" fill="currentColor"/>',
    "facebook": '<path d="M14.5 8.5V7c0-.9.4-1.5 1.4-1.5H17V3.1c-.7-.1-1.5-.1-2.3-.1-2.2 0-3.7 1.3-3.7 3.7v1.8H8.5v3h2.5V21h3.5v-9.5h2.6l.4-3h-3Z" fill="currentColor"/>',
    "tiktok": '<path d="M15.4 3.5c.3 2.1 1.6 3.5 3.6 3.8v2.9c-1.4 0-2.7-.4-3.8-1.2v5.9a5.4 5.4 0 1 1-5.4-5.4c.3 0 .6 0 .9.1v3a2.5 2.5 0 1 0 1.7 2.3V3.5h3Z" fill="currentColor"/>',
    "linkedin": '<rect x="3.5" y="3.5" width="17" height="17" rx="2.5" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M7.7 10v6.3M7.7 7.6v.1M11.4 16.3V10m0 2.1c.5-1 1.4-1.6 2.6-1.6 1.9 0 2.8 1.2 2.8 3.2v2.6" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>',
}


def icon(name, cls="icon"):
    return (
        f'<svg class="{cls}" viewBox="0 0 24 24" aria-hidden="true" focusable="false">'
        f'{ICONS[name]}</svg>'
    )


def brand_mark(base, light=False):
    return f'''<span class="brand-mark" aria-hidden="true">
          <svg viewBox="0 0 48 48" focusable="false">
            <defs>
              <linearGradient id="dcArc{'Light' if light else ''}" x1="8" y1="4" x2="40" y2="44" gradientUnits="userSpaceOnUse">
                <stop offset="0" stop-color="#FDBA74"></stop>
                <stop offset="1" stop-color="#F97316"></stop>
              </linearGradient>
            </defs>
            <path d="M24 6a18 18 0 1 0 18 18" fill="none" stroke="url(#dcArc{'Light' if light else ''})" stroke-width="5" stroke-linecap="round"></path>
            <path class="brand-fork" d="M20 15v5a4 4 0 0 0 8 0v-5M24 15v5.5M24 24v9" fill="none" stroke-width="2.4" stroke-linecap="round"></path>
          </svg>
        </span>'''


NAV_ITEMS = [
    ("How It Works", "how-it-works.html", "how"),
    ("Dining Experiences", "experiences.html", "experiences"),
    ("For Restaurants", "for-restaurants.html", "for-restaurants"),
    ("For Hosts", "for-hosts.html", "for-hosts"),
    ("About", "about.html", "about"),
]


def city_picker(base):
    """City switcher. It lives in the restaurants filter bar, not the header:
    the header's job on this site is the two conversions, and a city control
    that only offers one live city belongs next to the listings it filters."""
    return f'''<div class="city-picker" data-city-picker>
            <button class="city-btn" type="button" aria-expanded="false" aria-haspopup="listbox" aria-controls="cityMenu">
              {icon("pin")}<span data-city-label>Karachi</span>{icon("chevron", "icon icon--sm chevron")}
            </button>
            <ul class="city-menu" id="cityMenu" role="listbox" aria-label="Choose a city" hidden>
              <li role="option" aria-selected="true" tabindex="-1" data-city="Karachi"><span>Karachi</span><span class="pill pill--live">Live</span></li>
              <li role="option" aria-selected="false" aria-disabled="true" tabindex="-1" data-city="Lahore"><span>Lahore</span><span class="pill">Soon</span></li>
              <li role="option" aria-selected="false" aria-disabled="true" tabindex="-1" data-city="Islamabad"><span>Islamabad</span><span class="pill">Soon</span></li>
            </ul>
          </div>'''


def header(base, active):
    nav = ""
    for label, path, key in NAV_ITEMS:
        current = ' aria-current="page"' if key == active else ""
        nav += f'<li><a href="{base}{path}"{current}>{label}</a></li>\n          '
    return f'''<header class="site-header" data-header>
      <div class="container header-inner">
        <a class="brand" href="{base}index.html" aria-label="DineCircle home">
          {brand_mark(base)}
          <span class="brand-word">Dine<span>Circle</span></span>
        </a>
        <nav class="primary-nav" id="primaryNav" aria-label="Primary">
          <ul>
          {nav}</ul>
          <div class="nav-extra">
            <a class="btn btn--primary" href="{base}download.html">Download App</a>
            <a class="btn btn--outline" href="{base}become-a-partner.html">Become a Partner</a>
          </div>
        </nav>
        <div class="header-actions">
          <a class="btn btn--primary btn--sm header-cta" href="{base}download.html">Download App</a>
          <a class="btn btn--outline btn--sm header-cta" href="{base}become-a-partner.html">Become a Partner</a>
          <button class="nav-toggle" type="button" aria-expanded="false" aria-controls="primaryNav" aria-label="Open menu" data-nav-toggle>
            <span></span><span></span><span></span>
          </button>
        </div>
      </div>
    </header>'''


FOOTER_COLUMNS = [
    ("Diners", [
        ("How It Works", "how-it-works.html"),
        ("Dining Experiences", "experiences.html"),
        ("Restaurants", "restaurants.html"),
        ("Deals", "deals.html"),
        ("Download App", "download.html"),
    ]),
    ("Partners", [
        ("For Restaurants", "for-restaurants.html"),
        ("Become a Partner", "become-a-partner.html"),
        ("Partner pricing", "for-restaurants.html#pricing"),
        ("For Hosts", "for-hosts.html"),
        ("Become a Host", "for-hosts.html#become"),
    ]),
    ("Company", [
        ("About DineCircle", "about.html"),
        ("Contact & Support", "contact.html"),
        ("Press enquiries", "contact.html?topic=press"),
    ]),
    ("Legal", [
        ("Privacy Policy", "privacy.html"),
        ("Terms of Service", "terms.html"),
        ("Community Guidelines", "community-guidelines.html"),
    ]),
]


def footer(base):
    cols = ""
    for title, links in FOOTER_COLUMNS:
        items = "".join(f'<li><a href="{base}{href}">{label}</a></li>' for label, href in links)
        cols += f'<div class="footer-col"><h3>{title}</h3><ul>{items}</ul></div>'
    social_links = "".join(
        f'<a href="{url}" target="_blank" rel="noopener noreferrer" '
        f'aria-label="DineCircle on {name}">{icon(name.lower())}</a>'
        for name, url in SOCIAL
    )
    socials = (
        f'<div class="socials" aria-label="Social channels">{social_links}</div>'
        if social_links
        else ""
    )
    f = figures()
    return f'''<footer class="site-footer">
      <div class="container footer-grid">
        <div class="footer-brand">
          <a class="brand brand--light" href="{base}index.html" aria-label="DineCircle home">
            {brand_mark(base, light=True)}
            <span class="brand-word">Dine<span>Circle</span></span>
          </a>
          <p class="footer-tagline">{TAGLINE}</p>
          <p>DineCircle helps you discover restaurants, deals and hosted dining experiences, then gets you out of the house and to a good table. {f["venues"]} venues and {f["experiences"]} experiences live in Karachi today.</p>
          {socials}
        </div>
        {cols}
        <div class="footer-col footer-contact">
          <h3>Support</h3>
          <ul>
            <li><a href="mailto:{SUPPORT_EMAIL}">{SUPPORT_EMAIL}</a></li>
            <li><a href="mailto:{EMAIL}">{EMAIL}</a></li>
            <li><a href="mailto:{PARTNER_EMAIL}">{PARTNER_EMAIL}</a></li>
            <li>{LOCATION}</li>
            <li>{SUPPORT_HOURS}</li>
          </ul>
          <a class="btn btn--light btn--sm" href="{base}download.html">Download App</a>
        </div>
      </div>
      <div class="container footer-bottom">
        <p>&copy; 2026 DineCircle. Free for diners, always.</p>
        <p class="footer-fine">{LOCATION.split(",")[0]} pilot &middot; Prices in PKR &middot; Preview content for venue menus and offers.</p>
      </div>
    </footer>'''


def app_dialog(base):
    return f'''<dialog class="modal" id="appDialog" aria-labelledby="appDialogTitle">
      <div class="modal-card">
        <button class="modal-close" type="button" data-close-dialog aria-label="Close">{icon("close")}</button>
        <span class="modal-icon">{icon("verified")}</span>
        <h2 id="appDialogTitle">DineCircle is free for diners</h2>
        <p>Book a table, join a hosted experience or redeem a deal in the app. No booking fee and no card details. You pay the restaurant directly.</p>
        <ul class="check-list">
          <li>{icon("check")} Free to browse, book and join</li>
          <li>{icon("check")} 0% booking commission</li>
          <li>{icon("check")} Prices in PKR, settled at the venue</li>
        </ul>
        <div class="modal-actions">
          <a class="btn btn--primary" href="{base}download.html">See app availability</a>
          <a class="btn btn--outline" href="{base}contact.html">Contact us</a>
        </div>
        <p class="modal-note">Android and iOS apps are rolling out across Karachi.</p>
      </div>
    </dialog>'''


def page(title, description, base, active, body, og="assets/images/hero_tasting.webp", body_class=""):
    full_title = title if "DineCircle" in title else f"{title} · DineCircle"
    return f'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{esc(full_title)}</title>
  <meta name="description" content="{esc(description)}">
  <meta name="theme-color" content="#F97316">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="DineCircle">
  <meta property="og:title" content="{esc(full_title)}">
  <meta property="og:description" content="{esc(description)}">
  <meta property="og:image" content="{base}{og}">
  <link rel="icon" href="{base}favicon.svg" type="image/svg+xml">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600;700&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="{base}assets/css/base.css">
  <link rel="stylesheet" href="{base}assets/css/components.css">
  <link rel="stylesheet" href="{base}assets/css/pages.css">
  <script src="{base}assets/js/site.js" defer></script>
</head>
<body class="{body_class}">
  <a class="skip-link" href="#main">Skip to content</a>
  {header(base, active)}
  <main id="main">
{body}
  </main>
  {footer(base)}
  {app_dialog(base)}
  <div class="toast" id="toast" role="status" aria-live="polite"></div>
</body>
</html>'''


def img(base, name, alt, cls="", eager=False):
    loading = ' fetchpriority="high"' if eager else ' loading="lazy"'
    return f'<img class="{cls}" src="{base}assets/images/{name}.webp" alt="{esc(alt)}"{loading} decoding="async">'


def section_head(eyebrow, title, note="", action="", light=False):
    cls = "section-head section-head--light" if light else "section-head"
    action_html = f'<div class="section-action">{action}</div>' if action else ""
    note_html = f'<p class="section-note">{note}</p>' if note else ""
    return f'''<div class="{cls}">
        <div class="section-head__text">
          <p class="eyebrow">{eyebrow}</p>
          <h2>{title}</h2>
          {note_html}
        </div>
        {action_html}
      </div>'''


def crumbs(base, items, light=False):
    parts = []
    for i, (label, href) in enumerate(items):
        if href:
            parts.append(f'<li><a href="{base}{href}">{label}</a></li>')
        else:
            parts.append(f'<li aria-current="page">{label}</li>')
    cls = "breadcrumbs breadcrumbs--light" if light else "breadcrumbs"
    return f'<nav class="{cls}" aria-label="Breadcrumb"><ol>{"".join(parts)}</ol></nav>'


def verified_pill():
    return f'<span class="pill pill--verified">{icon("verified", "icon icon--xs")} Verified partner</span>'


def seats_left(exp):
    return exp["seats"] - exp["booked"]


def seat_meter(exp, compact=True):
    left = seats_left(exp)
    pct = round(exp["booked"] / exp["seats"] * 100)
    return f'''<div class="seat-row">
            <div class="seat-meter" role="progressbar" aria-valuemin="0" aria-valuemax="{exp["seats"]}" aria-valuenow="{exp["booked"]}" aria-label="{left} of {exp["seats"]} seats left"><span style="width:{pct}%"></span></div>
            <span class="seat-left">{left} of {exp["seats"]} seats left</span>
          </div>'''


def venue_card(v, base):
    preview = ""
    for section in v["menu"][:2]:
        for item in section["items"][:2]:
            preview += f'<li><span>{esc(item["name"])}</span><span>{money(item["price"])}</span></li>'
        if preview.count("<li>") >= 3:
            break
    first_deal = v["deals"][0]
    badges = ""
    if v["verified"]:
        badges += '<span class="badge badge--verified">Verified partner</span>'
    badges += f'<span class="badge badge--offer">{esc(first_deal["label"])}</span>'
    return f'''<article class="venue-card" data-venue-card data-cuisines="{" ".join(cuisines_for_filter(v))}" data-price="{len(v["price"])}" data-name="{esc(v["name"].lower())}" data-search="{esc(venue_search_blob(v))}">
          <a class="venue-card__media" href="{base}restaurants/{v["slug"]}.html" aria-label="View {esc(v["name"])}">
            {img(base, v["cover"], f'{v["name"]}: {v["tagline"]}')}
            <div class="badge-row">{badges}</div>
          </a>
          <div class="venue-card__body">
            <div class="venue-card__title">
              <h3><a href="{base}restaurants/{v["slug"]}.html">{esc(v["name"])}</a></h3>
              <span class="price-tier" aria-label="Price range">{v["price"]}</span>
            </div>
            <p class="meta-line">{icon("pin")} {esc(v["area"])}</p>
            <p class="cuisine-line">{" · ".join(v["cuisines"])}</p>
            <ul class="menu-preview">{preview}</ul>
            <div class="venue-card__foot">
              <a class="text-link" href="{base}restaurants/{v["slug"]}.html">View Menu {icon("arrow", "icon icon--sm")}</a>
              <span class="open-pill" data-hours data-open="{v["open"]}" data-close="{v["close"]}" data-closed="{",".join(v["closed"])}">See hours</span>
            </div>
          </div>
        </article>'''


def deal_card(d, base, show_contact=True):
    v = VENUE_BY_SLUG[d["venue"]]
    code = ""
    if d["code"]:
        code = f'''<button class="code" type="button" data-copy="{esc(d["code"])}" aria-label="Copy code {esc(d["code"])}"><span>{esc(d["code"])}</span>{icon("check", "icon icon--xs")}</button>'''
    else:
        code = '<span class="code code--none">No code needed</span>'
    redeem = f'<p class="deal-redeem">{esc(d["redeem"])}</p>' if show_contact else ""
    return f'''<article class="deal-card" data-deal-card data-cuisines="{" ".join(cuisines_for_filter(v))}" data-search="{esc((v["name"] + " " + d["title"] + " " + d["desc"] + " " + d["terms"]).lower())}">
          <div class="deal-card__media">
            {img(base, d["img"], d["title"])}
            <span class="deal-label">{esc(d["label"])}</span>
          </div>
          <div class="deal-card__body">
            <p class="eyebrow eyebrow--sm"><a href="{base}restaurants/{v["slug"]}.html">{esc(v["name"])}</a> · {esc(v["area"])}</p>
            <h3>{esc(d["title"])}</h3>
            <p>{esc(d["desc"])}</p>
            <p class="deal-terms"><strong>Terms:</strong> {esc(d["terms"])}</p>
            {redeem}
            <div class="deal-card__foot">
              {code}
              <a class="text-link" href="{base}restaurants/{v["slug"]}.html">View venue {icon("arrow", "icon icon--sm")}</a>
            </div>
          </div>
        </article>'''


def exp_card(e, base):
    v, h = e["venue_obj"], e["host_obj"]
    return f'''<article class="exp-card" data-exp-card data-type="{e["type"]}">
          <a class="exp-card__media" href="{base}experiences/{e["slug"]}.html" aria-label="{esc(e["title"])}">
            {img(base, e["cover"], e["title"])}
            <time class="date-badge" data-date data-format="badge" data-offset="{e["offset"]}" data-hour="{e["hour"]}" data-minute="{e["minute"]}">
              <span class="date-dow">Upcoming</span><span class="date-day"></span>
            </time>
            <span class="type-badge">{e["type"].title()}</span>
          </a>
          <div class="exp-card__body">
            <p class="eyebrow eyebrow--sm">Hosted by <a href="{base}hosts/{h["slug"]}.html">{esc(h["name"])}</a></p>
            <h3><a href="{base}experiences/{e["slug"]}.html">{esc(e["title"])}</a></h3>
            <p class="exp-tagline">{esc(e["tagline"])}</p>
            <p class="meta-line">{icon("pin")} <a href="{base}restaurants/{v["slug"]}.html">{esc(v["name"])}</a> · {esc(v["area"])}</p>
            {seat_meter(e)}
            <div class="exp-card__foot">
              <span class="price-note"><strong>{money(e["price"])}</strong><small>est. dining, paid at venue</small></span>
              <a class="btn btn--outline btn--sm" href="{base}experiences/{e["slug"]}.html">View Experience</a>
            </div>
          </div>
        </article>'''


def host_card(h, base):
    count = len(h["experiences"])
    label = f'{count} upcoming {"experience" if count == 1 else "experiences"}'
    return f'''<article class="host-card">
          <a class="host-card__media" href="{base}hosts/{h["slug"]}.html" aria-label="{esc(h["name"])}">
            {img(base, h["portrait"], f'{h["name"]}: {h["role"]}')}
          </a>
          <div class="host-card__body">
            <h3><a href="{base}hosts/{h["slug"]}.html">{esc(h["name"])}</a></h3>
            <p class="handle">@{esc(h["handle"])}</p>
            <p class="host-specialty">{esc(h["specialty"])}</p>
            <div class="host-card__foot">
              <span>{label}</span>
              <a class="round-arrow" href="{base}hosts/{h["slug"]}.html" aria-label="View {esc(h["name"])}">{icon("arrow", "icon icon--sm")}</a>
            </div>
          </div>
        </article>'''


def empty_state(msg, hint):
    return f'''<div class="empty-state" data-empty hidden>
        <span class="empty-icon">{icon("search")}</span>
        <p class="empty-title">{msg}</p>
        <p>{hint}</p>
        <button class="btn btn--primary btn--sm" type="button" data-clear-filters>Clear filters</button>
      </div>'''


# ---------------------------------------------------------------------------
# Marketing components
# ---------------------------------------------------------------------------

# Real Customer App captures, prepared by tool/app_shots.py. Each is a screen a
# visitor reaches in the shipping app; the label doubles as the frame caption.
APP_SHOTS = [
    ("app_home", "Home", "Tonight's trending tables, bookings and quick actions."),
    ("app_explore", "Explore", "Search a dish, a cuisine or an occasion across the city."),
    ("app_deals", "Deals", "The discount, the validity and what is included, before you order."),
]

STORE_META = {
    "android": ("Google Play", "Android", "Android 7.0 or later"),
    "ios": ("App Store", "iPhone", "iOS 15 or later"),
}


def qr_target():
    return (SITE_URL or "https://dinecircle.app") + "/download.html"


def qr_block(base=""):
    target = qr_target()
    return f'''<figure class="qr-card">
          <img src="{base}assets/images/qr-download.svg" alt="QR code that opens {esc(target)}" width="180" height="180" loading="lazy" decoding="async">
          <figcaption>Scan with your phone camera to open this page</figcaption>
        </figure>'''


def store_badge(platform):
    """One store button. Without a link it stays a non-interactive badge, which
    is the honest state while a listing has not cleared review."""
    name, os_name, _requirement = STORE_META[platform]
    url = STORE_LINKS.get(platform, "")
    if url:
        return f'''<a class="store-badge" href="{esc(url)}" target="_blank" rel="noopener noreferrer">
            <span class="store-badge__icon">{icon("download")}</span>
            <span class="store-badge__text"><small>Get it on</small><strong>{name}</strong></span>
          </a>'''
    return f'''<span class="store-badge store-badge--pending">
            <span class="store-badge__icon">{icon("clock")}</span>
            <span class="store-badge__text"><small>{os_name}</small><strong>{name}</strong><em>Coming soon</em></span>
          </span>'''


def store_row():
    return f'<div class="store-row">{store_badge("android")}{store_badge("ios")}</div>'


def phone_frame(name, label, caption, base=""):
    return f'''<figure class="app-shot">
          <span class="phone-frame">{img(base, name, f"{label} screen in the DineCircle app")}</span>
          <figcaption><strong>{label}</strong><span>{caption}</span></figcaption>
        </figure>'''


def app_stage(base=""):
    shots = "".join(phone_frame(name, label, caption, base) for name, label, caption in APP_SHOTS)
    return f'<div class="app-stage">{shots}</div>'


def app_phone_crop(name, alt):
    """One framed app capture, for pages that only need a single screen."""
    return f'<span class="phone-frame phone-frame--single">{img("", name, alt)}</span>'


def field(label, name, kind="text", required=False, placeholder="", autocomplete="", options=None, rows=None, wide=False):
    req = " required" if required else ""
    star = ' <span class="req" aria-hidden="true">*</span>' if required else ""
    ph = f' placeholder="{esc(placeholder)}"' if placeholder else ""
    if options:
        control = f'<select name="{name}"{req}>' + "".join(
            f'<option value="{esc(value)}">{esc(text)}</option>' for value, text in options
        ) + "</select>"
    elif rows:
        control = f'<textarea name="{name}" rows="{rows}"{req}{ph}></textarea>'
    else:
        ac = f' autocomplete="{autocomplete}"' if autocomplete else ""
        control = f'<input type="{kind}" name="{name}"{req}{ac}{ph}>'
    cls = "field field--wide" if wide else "field"
    return f'<label class="{cls}"><span>{label}{star}</span>{control}</label>'


def lead_form(kind, fields, submit_label, note, cls="lead-form"):
    """Shared lead form shell. Every form carries its own endpoint and kind so
    one handler in site.js serves partner applications, waitlist and contact.
    The honeypot is hidden from people and filled by the bots that ignore CSS."""
    return f'''<form class="{cls}" data-lead-form data-lead-kind="{kind}" data-lead-api="{esc(LEAD_API)}">
          {fields}
          <div class="field-hp" aria-hidden="true">
            <label for="{kind}-website">Leave this field empty</label>
            <input id="{kind}-website" type="text" name="website" tabindex="-1" autocomplete="off">
          </div>
          <div class="lead-actions">
            <button class="btn btn--primary" type="submit">{submit_label}</button>
            <p class="form-status" data-lead-status role="status" aria-live="polite"></p>
          </div>
          <p class="form-note">{note}</p>
        </form>'''


def cta_band(eyebrow, title, body, primary, secondary):
    return f'''<section class="cta-band">
      <div class="container cta-band__inner">
        <div>
          <p class="eyebrow">{eyebrow}</p>
          <h2>{title}</h2>
          <p>{body}</p>
        </div>
        <div class="cta-band__actions">
          {primary}
          {secondary}
        </div>
      </div>
    </section>'''


def faq_section(title, kinds, note="", limit=None):
    note_html = f'<p class="section-note">{note}</p>' if note else ""
    return f'''<section class="section section--cream" id="faq">
      <div class="container faq-layout">
        <div>
          <p class="eyebrow">FAQs</p>
          <h2>{title}</h2>
          {note_html}
        </div>
        <div class="faq-list">{faq_html(kinds, limit)}</div>
      </div>
    </section>'''


def steps_four(steps):
    items = ""
    for num, ic, title, body in steps:
        items += f'''<li class="step">
            <span class="step-num">{num}</span>
            <span class="step-icon">{icon(ic)}</span>
            <h3>{title}</h3>
            <p>{body}</p>
          </li>'''
    return f'<ol class="steps steps--four">{items}</ol>'

# ---------------------------------------------------------------------------
# Page helpers
# ---------------------------------------------------------------------------

DAY_ROWS = [("Monday", "mon"), ("Tuesday", "tue"), ("Wednesday", "wed"), ("Thursday", "thu"),
            ("Friday", "fri"), ("Saturday", "sat"), ("Sunday", "sun")]


def to_12h(value):
    hour, minute = [int(x) for x in value.split(":")]
    suffix = "AM" if hour < 12 else "PM"
    display = hour % 12 or 12
    return f"{display}:{minute:02d} {suffix}"


def tag_pill(tag):
    key = tag.lower()
    if key == "spicy":
        cls = "tag-pill tag-pill--spicy"
    elif key in ("vegetarian", "vegan"):
        cls = "tag-pill tag-pill--veg"
    elif key == "seafood":
        cls = "tag-pill tag-pill--sea"
    elif key in ("popular", "chef's pick", "bestseller"):
        cls = "tag-pill tag-pill--pick"
    else:
        cls = "tag-pill"
    return f'<span class="{cls}">{esc(tag)}</span>'


def page_hero(eyebrow, title, lede, extra="", crumbs_html=""):
    return f'''<section class="page-hero">
      <div class="container">
        {crumbs_html}
        <p class="eyebrow">{eyebrow}</p>
        <h1>{title}</h1>
        <p class="page-lede">{lede}</p>
        {extra}
      </div>
    </section>'''


def hours_table(v):
    rows = ""
    for label, code in DAY_ROWS:
        if code in v["closed"]:
            value = '<span class="closed">Closed</span>'
        else:
            value = f'{to_12h(v["open"])} – {to_12h(v["close"])}'
        rows += f'<tr><th scope="row">{label}</th><td>{value}</td></tr>'
    return f'<div class="hours-table"><table><caption class="sr-only">Opening hours for {esc(v["name"])}</caption><tbody>{rows}</tbody></table></div>'


def venue_menu(v, base=""):
    nav = "".join(
        f'<a class="chip chip--anchor" href="#menu-{i}">{esc(s["name"])}</a>'
        for i, s in enumerate(v["menu"])
    )
    sections = ""
    for i, s in enumerate(v["menu"]):
        items = ""
        for item in s["items"]:
            thumb = ""
            if item["img"]:
                thumb = f'<span class="menu-item__thumb">{img(base, item["img"], item["name"])}</span>'
            tags = "".join(tag_pill(t) for t in item["tags"])
            items += f'''<li class="menu-item">
                <div class="menu-item__main">
                  <div class="menu-item__head"><h4>{esc(item["name"])}</h4><span class="menu-item__price">{money(item["price"])}</span></div>
                  <p>{esc(item["desc"])}</p>
                  <div class="tag-row">{tags}</div>
                </div>
                {thumb}
              </li>'''
        sections += f'''<section class="menu-section" id="menu-{i}">
            <div class="menu-section__head"><h3>{esc(s["name"])}</h3><span>{len(s["items"])} dishes</span></div>
            <ul class="menu-list">{items}</ul>
          </section>'''
    return f'<div class="menu-jump">{nav}</div>{sections}'


# ---------------------------------------------------------------------------
# Home
# ---------------------------------------------------------------------------

def build_home():
    f = figures()
    featured = [v for v in VENUES if v.get("featured")]
    if len(featured) < 4:
        featured += [v for v in VENUES if v not in featured]
    featured_cards = "".join(venue_card(v, "") for v in featured[:4])

    # Three offers taken at even spacing rather than by list position, so adding
    # a venue can never silently reshape the homepage.
    step = max(1, len(ALL_DEALS) // 3)
    home_deals = [ALL_DEALS[i * step] for i in range(3)]
    deal_cards = "".join(deal_card(d, "", show_contact=False) for d in home_deals)
    exp_cards = "".join(exp_card(e, "") for e in EXPERIENCES[:3])

    host_chips = ""
    for h in HOSTS[:3]:
        host_chips += (
            '<a class="host-chip" href="hosts/' + h["slug"] + '.html">'
            + img("", h["portrait"], h["name"] + ": " + h["role"], cls="host-chip__photo")
            + '<span><strong>' + esc(h["name"]) + '</strong><small>'
            + esc(h["specialty"]) + '</small></span></a>'
        )

    cuisine_chips = "".join(
        f'<a class="chip" href="restaurants.html?cuisine={c}">{label}</a>'
        for c, label in [
            ("pakistani", "Pakistani"), ("bbq", "BBQ"), ("seafood", "Seafood"),
            ("cafe", "Cafés"), ("italian", "Italian"), ("mediterranean", "Mediterranean"),
            ("desserts", "Desserts"), ("brunch", "Brunch"),
        ]
    )

    body = f'''<section class="editorial-hero" data-hero-carousel role="region" aria-roledescription="carousel" aria-label="Discover DineCircle" tabindex="0">
      <div class="editorial-hero__slides">
        <article class="editorial-slide is-active" data-hero-slide role="group" aria-roledescription="slide" aria-label="1 of 3: Discover DineCircle">
          <img class="editorial-slide__image" src="assets/images/venue_rooftop.webp" alt="A restaurant terrace glowing under evening lights" fetchpriority="high" decoding="async">
          <div class="container editorial-slide__inner">
            <div class="editorial-slide__copy">
              <p class="editorial-kicker"><span></span> DineCircle &middot; Karachi</p>
              <h1>Great Food.<br><em>Better Connections.</em></h1>
              <p class="editorial-slide__description">Discover restaurants, unlock dining deals, and meet people through unforgettable food experiences.</p>
              <div class="editorial-slide__actions"><a class="btn btn--primary" href="download.html">Download App <span aria-hidden="true">↗</span></a><a class="editorial-link" href="for-restaurants.html">For Restaurants <span aria-hidden="true">→</span></a></div>
              <p class="editorial-slide__assurance">{f["venues"]} venues <span aria-hidden="true">&middot;</span> {f["offers"]} live deals <span aria-hidden="true">&middot;</span> 0% booking commission</p>
            </div>
            <div class="editorial-slide__caption"><span>01 / THE DINECIRCLE EDIT</span><strong>Great food, better connections</strong></div>
          </div>
        </article>
        <article class="editorial-slide" data-hero-slide role="group" aria-roledescription="slide" aria-label="2 of 3: Dining deals" hidden inert>
          <img class="editorial-slide__image" src="assets/images/dish_steak.webp" alt="A beautifully plated dinner ready to be enjoyed" loading="lazy" decoding="async">
          <div class="container editorial-slide__inner">
            <div class="editorial-slide__copy">
              <p class="editorial-kicker"><span></span> Good food. Clear value.</p>
              <h2>Find your favourite.<br><em>Savour the value.</em></h2>
              <p class="editorial-slide__description">Explore dining deals with clear prices and terms. See what is included, check when an offer applies, and choose what works for your table.</p>
              <div class="editorial-slide__actions"><a class="btn btn--primary" href="download.html">Download App <span aria-hidden="true">↗</span></a><a class="editorial-link" href="for-restaurants.html">Become a Partner <span aria-hidden="true">→</span></a></div>
              <p class="editorial-slide__assurance">Deals are redeemed at the table <span aria-hidden="true">&middot;</span> No checkout</p>
            </div>
            <div class="editorial-slide__caption"><span>02 / THE DINECIRCLE EDIT</span><strong>A little extra to savour</strong></div>
          </div>
        </article>
        <article class="editorial-slide" data-hero-slide role="group" aria-roledescription="slide" aria-label="3 of 3: Hosted experiences" hidden inert>
          <img class="editorial-slide__image" src="assets/images/venue_bar.webp" alt="Guests settling in at a warmly lit restaurant bar" loading="lazy" decoding="async">
          <div class="container editorial-slide__inner">
            <div class="editorial-slide__copy">
              <p class="editorial-kicker"><span></span> Food brings us together</p>
              <h2>A reason to go out.<br><em>A table to share.</em></h2>
              <p class="editorial-slide__description">From a relaxed brunch to a shared dinner, join experiences led by local hosts and food creators. Good food, fresh conversation, and a reason to get together.</p>
              <div class="editorial-slide__actions"><a class="btn btn--primary" href="download.html">Download App <span aria-hidden="true">↗</span></a><a class="editorial-link" href="for-hosts.html">Become a Host <span aria-hidden="true">→</span></a></div>
              <p class="editorial-slide__assurance">Joining is free <span aria-hidden="true">&middot;</span> You pay the venue for your meal</p>
            </div>
            <div class="editorial-slide__caption"><span>03 / THE DINECIRCLE EDIT</span><strong>More than a meal</strong></div>
          </div>
        </article>
      </div>
      <div class="container editorial-hero__bottom">
        <div class="editorial-tabs" role="group" aria-label="Choose a slide">
          <button type="button" data-hero-goto="0" aria-label="Show slide 1: Restaurants and cafés" aria-pressed="true"><span>01</span> Places to love</button>
          <button type="button" data-hero-goto="1" aria-label="Show slide 2: Dining offers" aria-pressed="false"><span>02</span> More to savour</button>
          <button type="button" data-hero-goto="2" aria-label="Show slide 3: Hosted experiences" aria-pressed="false"><span>03</span> Find your circle</button>
        </div>
        <div class="editorial-controls">
          <button type="button" data-hero-prev aria-label="Previous slide">←</button>
          <button type="button" data-hero-pause aria-label="Pause slideshow" aria-pressed="false">Ⅱ</button>
          <button type="button" data-hero-next aria-label="Next slide">→</button>
        </div>
      </div>
      <span class="sr-only" data-hero-status aria-live="polite" aria-atomic="true"></span>
    </section>
    <section class="discovery-bar" aria-label="Find your next table">
      <div class="container discovery-bar__inner">
        <div><span class="editorial-small">A city full of flavour</span><h2>Where do you want to eat?</h2></div>
        <form class="discovery-search" action="restaurants.html" method="get" role="search" data-search-form>
          <label class="sr-only" for="heroQuery">Search restaurants, dishes or cuisines</label>
          <span aria-hidden="true">⌕</span><input id="heroQuery" name="q" type="search" placeholder="Try BBQ, brunch or your favourite café" autocomplete="off">
          <button class="btn btn--primary" type="submit">Explore Restaurants <span aria-hidden="true">→</span></button>
        </form>
      </div>
      <div class="container discovery-bar__tags"><span>Follow your craving</span><a href="restaurants.html?q=BBQ">Smoky BBQ ↗</a><a href="restaurants.html?q=Brunch">Slow brunches ↗</a><a href="restaurants.html?q=Coffee">Coffee & conversation ↗</a><a href="restaurants.html?cuisine=seafood">By the sea ↗</a></div>
    </section>

    <section class="section" id="discover">
      <div class="container">
        {section_head("Discover DineCircle", "Restaurants, cafés, deals and dining experiences in one place",
                      "Every listing is supplied by the venue: menus with prices in PKR, opening hours, offers with their terms, and hosted tables you can join.",
                      '<a class="btn btn--outline" href="restaurants.html">Explore Restaurants</a>')}
        <div class="venue-grid">{featured_cards}</div>
        <div class="cuisine-rail">
          <span class="cuisine-rail__label">Browse by craving</span>
          <div class="chips">{cuisine_chips}</div>
        </div>
        <div class="discover-deals">
          <div class="discover-deals__head">
            <div>
              <p class="eyebrow">Deals</p>
              <h3>{f["offers"]} live offers, with the terms written down</h3>
            </div>
            <a class="text-link" href="deals.html">Discover Deals {icon("arrow", "icon icon--sm")}</a>
          </div>
          <div class="deal-grid deal-grid--three">{deal_cards}</div>
        </div>
      </div>
    </section>

    <section class="section section--cream" id="how-it-works">
      <div class="container">
        {section_head("How it works", "Discover. Explore. Join. Dine.",
                      "Four steps, no checkout and no wallet. The app holds the booking, the restaurant holds the table, and you settle the bill at the end of the meal.",
                      '<a class="btn btn--outline" href="how-it-works.html">Read the full guide</a>')}
        {steps_four([
            ("01", "search", "Discover", "Search restaurants, cafés and dishes across Karachi. Filter by cuisine, area or price and read the full menu before you go."),
            ("02", "spark", "Explore", "Compare the menu, the prices and the atmosphere. Deals show their terms up front, so you know the bill before you arrive."),
            ("03", "users", "Join", "Book a table or join a hosted experience in the app. Both are free, and your seat is held for the venue."),
            ("04", "check", "Dine", "Show your booking or deal at the venue, eat, and pay the restaurant directly. No in-app payment and no hidden fee."),
        ])}
      </div>
    </section>

    <section class="section" id="connections">
      <div class="container">
        {section_head("Real connections", "A reason to go out, and a table to share",
                      "Hosted dinners, brunches and coffee meetups across Karachi. Meet the host, see what to expect, and join the table that feels right for you.",
                      '<a class="btn btn--outline" href="experiences.html">Join Experience</a>')}
        <div class="exp-grid">{exp_cards}</div>
        <div class="host-rail">
          <div class="host-rail__intro">
            <p class="eyebrow">Your hosts</p>
            <h3>Local people who know where to eat</h3>
            <p>Every experience is led by a host or food creator who chose the venue, the menu and the format, so you are following a person, not a listing.</p>
            <a class="text-link" href="hosts.html">Discover Hosts {icon("arrow", "icon icon--sm")}</a>
          </div>
          <div class="host-rail__list">{host_chips}</div>
        </div>
      </div>
    </section>

    <section class="section section--cream" id="app-showcase">
      <div class="container">
        {section_head("The DineCircle app", "Menus, deals and bookings in one place",
                      "These are the real screens, not mockups. Browse before you leave the house, hold the table in the app, and settle the bill at the restaurant.",
                      '<a class="btn btn--primary" href="download.html">Download App</a>')}
        {app_stage()}
        <ul class="showcase-points">
          <li>{icon("book")} <strong>Full menus with PKR prices</strong><span>Every dish, every section, before you commit to a table.</span></li>
          <li>{icon("spark")} <strong>Deals with clear terms</strong><span>The discount, the minimum spend and the validity date, no surprises.</span></li>
          <li>{icon("users")} <strong>Experiences you can join</strong><span>Hosted tables with seats left, booked without a fee.</span></li>
        </ul>
      </div>
    </section>

    <section class="section" id="for-restaurants">
      <div class="container partner-panel">
        <div class="partner-copy">
          <p class="eyebrow">For restaurants &amp; cafés</p>
          <h2>Put your full menu on the map</h2>
          <p>List your venue, publish a QR-ready menu, run deals and host experiences. DineCircle charges a flat subscription and never a commission on your bookings, so a full room costs you nothing extra.</p>
          <ul class="check-list">
            <li>{icon("check")} PKR 5,000 per month or PKR 50,000 per year</li>
            <li>{icon("check")} 0% booking commission</li>
            <li>{icon("check")} No payment gateway or payout setup</li>
            <li>{icon("check")} Activation after bank transfer, JazzCash or Easypaisa</li>
          </ul>
          <div class="about-actions">
            <a class="btn btn--primary" href="become-a-partner.html">Become a Partner</a>
            <a class="btn btn--outline" href="restaurants.html">See what a listing looks like</a>
          </div>
        </div>
        <aside class="price-card">
          <p class="eyebrow eyebrow--sm">Partner plan</p>
          <p class="price-card__amount">Rs. 5,000<span>/ month</span></p>
          <p class="price-card__alt">or Rs. 50,000 per year</p>
          <hr>
          <ul class="check-list check-list--sm">
            <li>{icon("check")} Full menu and QR menu</li>
            <li>{icon("check")} Deals and redemption terms</li>
            <li>{icon("check")} Table reservations</li>
            <li>{icon("check")} Hosted experiences</li>
            <li>{icon("check")} Reviews and replies</li>
          </ul>
          <a class="btn btn--primary btn--block" href="become-a-partner.html">Start your application</a>
          <p class="aside-fine">Manual activation after payment verification. No commission on any booking.</p>
        </aside>
      </div>
    </section>

    <section class="section section--cream" id="become-a-host">
      <div class="container host-panel">
        <div>
          <p class="eyebrow">Become a host</p>
          <h2>Turn what you know about food into a table</h2>
          <p>Hosts and food creators plan dining experiences with Karachi venues: who comes, what gets served, and how the evening runs. Host accounts are free, and Host Studio inside the app is where an experience gets built and published.</p>
          <ul class="check-list">
            <li>{icon("check")} Switch to a Professional account in the app to unlock Host Studio</li>
            <li>{icon("check")} Set the menu and format with the venue</li>
            <li>{icon("check")} Guests join free and pay the venue for their own meal</li>
          </ul>
          <div class="about-actions">
            <a class="btn btn--primary" href="for-hosts.html">Become a Host</a>
            <a class="btn btn--outline" href="hosts.html">Meet the current hosts</a>
          </div>
        </div>
        <figure class="host-panel__figure">{img("", "portrait_2", "A DineCircle host welcoming guests to a shared table")}</figure>
      </div>
    </section>

    <section class="app-band" id="app" aria-label="Download the DineCircle app">
      <div class="container app-band__inner">
        <div class="app-band__copy">
          <p class="eyebrow">App download</p>
          <h2>Carry your next table in your pocket</h2>
          <p>Free to download and free to book. Menus, deals, tables and hosted experiences in one app, opening in phases across Karachi.</p>
          <ul class="check-list check-list--light">
            <li>{icon("check")} Free for diners, no subscription</li>
            <li>{icon("check")} No in-app payment and no wallet</li>
            <li>{icon("check")} Android 7.0 or later, iOS 15 or later</li>
          </ul>
          {store_row()}
          <p class="app-band__fine">Not listed on your store yet? <a href="download.html">See app availability</a> and leave your email for the invite.</p>
        </div>
        {qr_block()}
      </div>
    </section>
    
    {faq_section("Questions, answered", ["diner", "both"],
                 'Still stuck? Write to <a href="mailto:' + SUPPORT_EMAIL + '">' + SUPPORT_EMAIL + '</a> and we will reply within one working day.',
                 limit=6)}
    
    {cta_band("Your table is waiting",
              "Make your next meal a local discovery.",
              "Keep restaurants, menus, deals and dining experiences close at hand. Download the app and find your next favourite.",
              '<a class="btn btn--light" href="download.html">Download App</a>',
              '<a class="btn btn--ghost-light" href="become-a-partner.html">Become a Partner</a>')}'''

    return page(
        "Restaurants, Cafés & Dining in Karachi | DineCircle",
        "Discover restaurants and cafés, explore menus and deals, and find dining experiences near you. DineCircle is your local food guide, starting in Karachi.",
        "", "", body,
    )


# ---------------------------------------------------------------------------
# Restaurants directory
# ---------------------------------------------------------------------------

def build_restaurants():
    cards = "".join(venue_card(v, "") for v in VENUES)
    chips = "".join(
        f'<button class="chip" type="button" data-filter="{key}" aria-pressed="false">{label}</button>'
        for key, label in [
            ("all", "All"), ("pakistani", "Pakistani"), ("bbq", "BBQ"), ("seafood", "Seafood"),
            ("cafe", "Cafés"), ("italian", "Italian"), ("mediterranean", "Mediterranean"),
            ("desserts", "Desserts"), ("coffee", "Coffee"), ("brunch", "Brunch"),
        ]
    )
    body = f'''{page_hero(
        "Restaurants & cafés",
        "Find your next table",
        "From neighbourhood cafés to dinner by the sea, find places for your mood and craving. Explore cuisines, get a feel for the atmosphere, and browse menus with prices in PKR.",
        crumbs_html=crumbs("", [("Home", "index.html"), ("Restaurants", None)]),
    )}
    <section class="section section--flush">
      <div class="container">
        <div class="filter-panel" data-filter-panel>
          <div class="filter-bar-top">
            {city_picker("")}
            <p class="filter-city-note">Showing places in the city you picked. Other cities are on the way.</p>
          </div>
          <div class="filter-search">
            {icon("search")}
            <label class="sr-only" for="venueSearch">Search restaurants, dishes or areas</label>
            <input id="venueSearch" type="search" placeholder="Search a place, dish or area" autocomplete="off" data-venue-search>
            <button class="filter-clear" type="button" data-clear-search aria-label="Clear search" hidden>{icon("close")}</button>
          </div>
          <div class="filter-row">
            <div class="chips" role="group" aria-label="Filter by cuisine">
              {chips}
            </div>
            <div class="filter-selects">
              <label class="select-wrap"><span class="sr-only">Price range</span>
                <select data-price-filter>
                  <option value="all">Any price</option>
                  <option value="2">$$</option>
                  <option value="3">$$$</option>
                </select>
                {icon("chevron", "icon icon--sm")}
              </label>
              <label class="select-wrap"><span class="sr-only">Sort by</span>
                <select data-sort>
                  <option value="recommended">Recommended</option>
                  <option value="az">Name A–Z</option>
                  <option value="price-low">Price: low to high</option>
                  <option value="price-high">Price: high to low</option>
                </select>
                {icon("chevron", "icon icon--sm")}
              </label>
            </div>
          </div>
        </div>
        <div class="result-bar">
          <p class="result-count" data-result-count role="status" aria-live="polite">Showing 11 places</p>
          <p class="result-hint">Free to browse · pay at the restaurant</p>
        </div>
        <div class="venue-grid" id="venueGrid">{cards}</div>
        {empty_state("No places match those filters.", "Try a different dish, cuisine or price range.")}
        <div class="inline-cta">
          <div>
            <h3>Looking for something specific?</h3>
            <p>Tell us the dish or the occasion and we will point you to the right table.</p>
          </div>
          <a class="btn btn--outline" href="contact.html">Contact DineCircle</a>
        </div>
      </div>
    </section>'''
    return page(
        "Restaurants & cafés in Karachi",
        "Browse and filter Karachi restaurants and cafés on DineCircle. Menus, cuisine, price ranges, deals and opening hours.",
        "", "", body,
    )


# ---------------------------------------------------------------------------
# Restaurant detail
# ---------------------------------------------------------------------------

def build_venue(v):
    deals_html = "".join(
        f'''<article class="venue-deal">
          <div class="venue-deal__head"><span class="deal-label deal-label--sm">{esc(d["label"])}</span><h3>{esc(d["title"])}</h3></div>
          <p>{esc(d["desc"])}</p>
          <p class="deal-terms"><strong>Terms:</strong> {esc(d["terms"])}</p>
          <p class="deal-terms"><strong>How to redeem:</strong> {esc(d["redeem"])}</p>
          <div class="venue-deal__foot">
            {f'<button class="code" type="button" data-copy="{esc(d["code"])}"><span>{esc(d["code"])}</span>{icon("check", "icon icon--xs")}</button>' if d["code"] else '<span class="code code--none">No code needed</span>'}
            <span class="deal-redeem">Show at the table</span>
          </div>
        </article>'''
        for d in v["deals"]
    )
    amenities = "".join(f'<li>{icon("check", "icon icon--xs")} {esc(a)}</li>' for a in v["amenities"])
    exp = EXP_BY_SLUG.get(v.get("experience", ""))
    exp_teaser = ""
    if exp:
        h = exp["host_obj"]
        exp_teaser = f'''<aside class="aside-card aside-card--exp">
            <p class="eyebrow eyebrow--sm">Hosted here</p>
            <h3>{esc(exp["title"])}</h3>
            <p>{esc(exp["tagline"])}</p>
            <p class="meta-line">{icon("calendar")} <time data-date data-format="short" data-offset="{exp["offset"]}" data-hour="{exp["hour"]}" data-minute="{exp["minute"]}">Upcoming</time> · {esc(exp["menu_style"])}</p>
            <p class="aside-note">Hosted by <a href="../hosts/{h["slug"]}.html">{esc(h["name"])}</a> · {seats_left(exp)} seats left</p>
            <a class="text-link" href="../experiences/{exp["slug"]}.html">View experience {icon("arrow", "icon icon--sm")}</a>
          </aside>'''
    related = [x for x in VENUES if x["slug"] != v["slug"]][:3]
    related_cards = "".join(venue_card(x, "../") for x in related)
    map_url = f'https://www.google.com/maps/search/?api=1&query={v["lat"]},{v["lng"]}'

    body = f'''<div class="container detail-top">
      {crumbs("../", [("Home", "index.html"), ("Restaurants", "restaurants.html"), (v["name"], None)])}
    </div>
    <section class="venue-gallery">
      <div class="container gallery-grid">
        <figure class="gallery-main">{img("../", v["cover"], f'{v["name"]}: {v["tagline"]}', eager=True)}</figure>
        <figure class="gallery-side">{img("../", v["gallery"][0], f"Dish at {v['name']}")}</figure>
        <figure class="gallery-side">{img("../", v["gallery"][1] if len(v["gallery"]) > 1 else v["cover"], f"Interior at {v['name']}")}</figure>
      </div>
    </section>

    <section class="venue-head">
      <div class="container venue-head__inner">
        <div>
          <div class="badge-row badge-row--static">
            {verified_pill() if v["verified"] else '<span class="pill">Listed venue</span>'}
            <span class="pill pill--soft">{v["price"]} price range</span>
          </div>
          <h1>{esc(v["name"])}</h1>
          <p class="venue-tagline">{esc(v["tagline"])}</p>
          <p class="meta-line meta-line--lg">{icon("pin")} {esc(v["address"])} · {esc(v["area"])}</p>
          <p class="cuisine-line">{" · ".join(v["cuisines"])}</p>
        </div>
        <div class="venue-head__actions">
          <span class="open-pill open-pill--lg" data-hours data-open="{v["open"]}" data-close="{v["close"]}" data-closed="{",".join(v["closed"])}">See hours</span>
          <button class="btn btn--primary" type="button" data-app-cta>Book a table</button>
        </div>
      </div>
    </section>

    <section class="section section--flush detail-body">
      <div class="container detail-grid">
        <div class="detail-main">
          <section class="detail-block" id="menu">
            <div class="detail-block__head"><h2>The menu</h2><p>Prices are in PKR and set by the venue.</p></div>
            {venue_menu(v, "../")}
          </section>

          <section class="detail-block" id="deals">
            <div class="detail-block__head"><h2>Deals at {esc(v["name"])}</h2><p>Show the offer at the table. No code means just ask.</p></div>
            <div class="venue-deal-list">{deals_html}</div>
          </section>

          <section class="detail-block" id="about">
            <div class="detail-block__head"><h2>About this place</h2></div>
            <p class="detail-lede">{esc(v["about"])}</p>
            <h3 class="small-heading">Amenities</h3>
            <ul class="amenity-list">{amenities}</ul>
          </section>

          <section class="detail-block" id="hours">
            <div class="detail-block__head"><h2>Opening hours</h2><p>Local time in Karachi.</p></div>
            {hours_table(v)}
          </section>

          <section class="detail-block" id="location">
            <div class="detail-block__head"><h2>Location</h2></div>
            <div class="location-card">
              <div>
                <p class="location-address">{icon("pin")} {esc(v["address"])}</p>
                <p class="muted">Inside {esc(v["area"])}, Karachi.</p>
              </div>
              <a class="btn btn--outline btn--sm" href="{map_url}" target="_blank" rel="noopener noreferrer">Open in Maps {icon("arrow", "icon icon--sm")}</a>
            </div>
          </section>
        </div>

        <aside class="detail-aside">
          <div class="aside-card aside-card--booking">
            <p class="eyebrow eyebrow--sm">Book with DineCircle</p>
            <p class="aside-price">{v["price"]} <span>per person, typical</span></p>
            <ul class="check-list check-list--sm">
              <li>{icon("check")} Free to book, 0% commission</li>
              <li>{icon("check")} Pay the restaurant directly</li>
              <li>{icon("check")} Deals applied at the table</li>
            </ul>
            <button class="btn btn--primary btn--block" type="button" data-app-cta>Reserve a table</button>
            <a class="btn btn--outline btn--block" href="#deals">Discover Deals</a>
            <p class="aside-fine">Table bookings and experience seats are confirmed in the DineCircle app.</p>
          </div>
          {exp_teaser}
          <div class="aside-card">
            <p class="eyebrow eyebrow--sm">Contact the venue</p>
            <p class="aside-note">For large groups, dietary questions or accessibility requests, contact DineCircle and we will connect you with the venue.</p>
            <a class="text-link" href="../contact.html">Contact us {icon("arrow", "icon icon--sm")}</a>
          </div>
        </aside>
      </div>
    </section>

    <section class="section section--cream">
      <div class="container">
        {section_head("Keep exploring", "More places nearby", "", '<a class="btn btn--outline" href="../restaurants.html">Explore Restaurants</a>')}
        <div class="venue-grid">{related_cards}</div>
      </div>
    </section>'''

    return page(
        f'{v["name"]}: menu, deals and hours',
        f'{v["name"]} in {v["area"]}, Karachi: full menu with PKR prices, deals, opening hours and location.',
        "../", "", body, og=f'assets/images/{v["cover"]}.webp',
    )


# ---------------------------------------------------------------------------
# Deals directory
# ---------------------------------------------------------------------------

def build_deals():
    cards = "".join(deal_card(d, "") for d in ALL_DEALS)
    chips = "".join(
        f'<button class="chip" type="button" data-filter="{key}" aria-pressed="false">{label}</button>'
        for key, label in [
            ("all", "All"), ("pakistani", "Pakistani"), ("bbq", "BBQ"), ("cafe", "Cafés"),
            ("italian", "Italian"), ("mediterranean", "Mediterranean"), ("desserts", "Desserts"),
            ("coffee", "Coffee"), ("brunch", "Brunch"),
        ]
    )
    body = f'''{page_hero(
        "Deals",
        "Offers worth ordering",
        "Find dining deals across Karachi’s restaurants and cafés. Compare prices, see what’s included, and read the terms before you go. Offers are applied by the venue at the table.",
        crumbs_html=crumbs("", [("Home", "index.html"), ("Deals", None)]),
    )}
    <section class="section section--flush">
      <div class="container">
        <div class="filter-panel">
          <div class="filter-search">
            {icon("search")}
            <label class="sr-only" for="dealSearch">Search deals by venue or dish</label>
            <input id="dealSearch" type="search" placeholder="Search a venue, offer or dish" autocomplete="off" data-deal-search>
            <button class="filter-clear" type="button" data-clear-search aria-label="Clear search" hidden>{icon("close")}</button>
          </div>
          <div class="filter-row">
            <div class="chips" role="group" aria-label="Filter deals by cuisine">{chips}</div>
            <p class="result-count" data-deal-count role="status" aria-live="polite">22 offers</p>
          </div>
        </div>
        <div class="deal-grid" id="dealGrid">{cards}</div>
        {empty_state("No offers match that search.", "Try another venue, cuisine or dish.")}
        <div class="notice-card">
          <span class="notice-icon">{icon("spark")}</span>
          <div>
            <h3>How deals work</h3>
            <p>Find an offer, show it to your server before ordering, and the venue applies it to the bill. Some offers need a code; others just need you to ask. Deals cannot be combined unless the terms say so.</p>
          </div>
        </div>
      </div>
    </section>'''
    return page(
        "Deals at Karachi restaurants",
        f'Discover {len(ALL_DEALS)} restaurant and café deals in Karachi with clear terms, redemption steps and no online payment.',
        "", "", body,
    )

# ---------------------------------------------------------------------------
# Experiences directory
# ---------------------------------------------------------------------------

def build_experiences():
    cards = "".join(exp_card(e, "") for e in EXPERIENCES)
    body = f'''{page_hero(
        "Dining experiences",
        "Pull up a chair with people who love food",
        "Discover reasons to get out and share a table, from relaxed brunches to hosted dinners and coffee meetups around Karachi. Meet the host, explore the menu, and check the estimated dining cost before you join.",
        crumbs_html=crumbs("", [("Home", "index.html"), ("Experiences", None)]),
    )}
    <section class="section section--flush">
      <div class="container">
        <div class="filter-row filter-row--bar">
          <div class="chips" role="group" aria-label="Filter experiences">
            <button class="chip is-active" type="button" data-exp-filter="all" aria-pressed="true">All experiences</button>
            <button class="chip" type="button" data-exp-filter="dinner" aria-pressed="false">Dinners</button>
            <button class="chip" type="button" data-exp-filter="brunch" aria-pressed="false">Brunches</button>
            <button class="chip" type="button" data-exp-filter="workshop" aria-pressed="false">Workshops</button>
          </div>
          <p class="result-count" data-exp-count role="status" aria-live="polite">5 upcoming</p>
        </div>
        <div class="exp-grid exp-grid--list" id="expGrid">{cards}</div>
        <div class="empty-state" data-exp-empty hidden>
          <span class="empty-icon">{icon("search")}</span>
          <p class="empty-title">No experiences in this category yet.</p>
          <p>Try another category or check back soon.</p>
          <button class="btn btn--primary btn--sm" type="button" data-clear-exp>Show all experiences</button>
        </div>
        <div class="notice-card">
          <span class="notice-icon">{icon("users")}</span>
          <div>
            <h3>How joining works</h3>
            <p>Every experience is hosted by a creator or community host and capped at a small table. Joining is free and reserves your seat; the estimated dining cost shown is paid directly to the venue on the day. No online payment, no booking fee.</p>
          </div>
        </div>
      </div>
    </section>'''
    return page(
        "Dining experiences in Karachi",
        "Join hosted dinners, brunches and coffee meetups across Karachi. Free to join; you pay the venue for your meal.",
        "", "experiences", body,
    )


def build_experience(e):
    v, h = e["venue_obj"], e["host_obj"]
    included = "".join(f'<li>{icon("check")} {esc(item)}</li>' for item in e["included"])
    tags = "".join(f'<span class="tag-pill">{esc(t)}</span>' for t in e["tags"])
    related = [x for x in EXPERIENCES if x["slug"] != e["slug"]][:3]
    related_cards = "".join(exp_card(x, "../") for x in related)

    body = f'''<section class="exp-hero">
      <div class="exp-hero__media">{img("../", e["cover"], e["title"], eager=True)}</div>
      <div class="exp-hero__shade"></div>
      <div class="container exp-hero__content">
        {crumbs("../", [("Home", "index.html"), ("Experiences", "experiences.html"), (e["title"], None)], light=True)}
        <span class="type-badge type-badge--light">{e["type"].title()}</span>
        <h1>{esc(e["title"])}</h1>
        <p class="exp-hero__tagline">{esc(e["tagline"])}</p>
        <div class="exp-hero__meta">
          <span>{icon("calendar")} <time data-date data-format="long" data-offset="{e["offset"]}" data-hour="{e["hour"]}" data-minute="{e["minute"]}">Upcoming</time></span>
          <span>{icon("pin")} <a href="../restaurants/{v["slug"]}.html">{esc(v["name"])}</a></span>
          <span>{icon("users")} Hosted by <a href="../hosts/{h["slug"]}.html">{esc(h["name"])}</a></span>
        </div>
      </div>
    </section>

    <section class="section section--flush">
      <div class="container detail-grid exp-detail-grid">
        <div class="detail-main">
          <section class="detail-block">
            <div class="detail-block__head"><h2>About this experience</h2></div>
            <p class="detail-lede">{esc(e["desc"])}</p>
            <div class="tag-row">{tags}</div>
          </section>

          <section class="detail-block">
            <div class="detail-block__head"><h2>What's included</h2><p>Arranged by the host with {esc(v["name"])}.</p></div>
            <ul class="included-grid">{included}</ul>
          </section>

          <section class="detail-block">
            <div class="detail-block__head"><h2>The table</h2></div>
            <dl class="fact-list">
              <div><dt>Menu style</dt><dd>{esc(e["menu_style"])}</dd></div>
              <div><dt>Group size</dt><dd>{e["seats"]} seats</dd></div>
              <div><dt>Duration</dt><dd>{e["duration"]} minutes</dd></div>
              <div><dt>Dining cost</dt><dd>{money(e["price"])} per person, paid to the venue</dd></div>
            </dl>
            <div class="host-note">
              <span class="host-note__icon">{icon("spark")}</span>
              <div><strong>A note from {esc(h["name"])}</strong><p>{esc(e["note"])}</p></div>
            </div>
          </section>

          <section class="detail-block">
            <div class="detail-block__head"><h2>Your host</h2></div>
            <a class="person-strip" href="../hosts/{h["slug"]}.html">
              {img("../", h["portrait"], h["name"], "person-strip__avatar")}
              <span class="person-strip__body">
                <strong>{esc(h["name"])}</strong>
                <span>@{esc(h["handle"])} · {esc(h["specialty"])}</span>
                <span class="muted">{esc(h["bio"])}</span>
              </span>
              {icon("arrow", "icon icon--sm")}
            </a>
          </section>

          <section class="detail-block">
            <div class="detail-block__head"><h2>The venue</h2></div>
            <a class="place-strip" href="../restaurants/{v["slug"]}.html">
              {img("../", v["cover"], v["name"], "place-strip__photo")}
              <span class="place-strip__body">
                <strong>{esc(v["name"])}</strong>
                <span>{esc(v["area"])} · {" · ".join(v["cuisines"])}</span>
                <span class="muted">{esc(v["tagline"])}</span>
              </span>
              {icon("arrow", "icon icon--sm")}
            </a>
          </section>

          <section class="detail-block">
            <div class="detail-block__head"><h2>Good to know</h2></div>
            <ul class="bullet-list">
              <li>Joining is free. The estimated dining cost is paid to {esc(v["name"])} on the day.</li>
              <li>Seats are limited to {e["seats"]} and are reserved when you join in the app.</li>
              <li>Come alone or bring a friend. The host seats the table and handles introductions.</li>
              <li>Tell the host about allergies or dietary needs when you join so the venue can prepare.</li>
            </ul>
          </section>
        </div>

        <aside class="detail-aside">
          <div class="aside-card aside-card--booking">
            <p class="eyebrow eyebrow--sm">Join this experience</p>
            <p class="aside-date"><time data-date data-format="long" data-offset="{e["offset"]}" data-hour="{e["hour"]}" data-minute="{e["minute"]}">Upcoming</time></p>
            <p class="aside-time">{icon("clock")} <time data-date data-format="range" data-offset="{e["offset"]}" data-hour="{e["hour"]}" data-minute="{e["minute"]}" data-duration="{e["duration"]}">Time</time> PKT</p>
            {seat_meter(e)}
            <div class="aside-price-row">
              <span><strong>{money(e["price"])}</strong><small>est. dining per person</small></span>
              <span class="pill pill--soft">Paid at venue</span>
            </div>
            <button class="btn btn--primary btn--block" type="button" data-app-cta>Join Experience</button>
            <p class="free-note">{icon("check", "icon icon--xs")} Joining is free · no booking fee</p>
            <ul class="check-list check-list--sm">
              <li>{icon("check")} Seats reserved in the app</li>
              <li>{icon("check")} Pay the venue directly on the day</li>
              <li>{icon("check")} Host handles introductions</li>
            </ul>
          </div>
          <div class="aside-card">
            <p class="eyebrow eyebrow--sm">Need help?</p>
            <p class="aside-note">Questions about the table, dietary needs or the venue? We answer within one working day.</p>
            <a class="text-link" href="../contact.html">Contact DineCircle {icon("arrow", "icon icon--sm")}</a>
          </div>
        </aside>
      </div>
    </section>

    <section class="section section--cream">
      <div class="container">
        {section_head("More to join", "Other upcoming tables", "", '<a class="btn btn--outline" href="../experiences.html">Explore Experiences</a>')}
        <div class="exp-grid">{related_cards}</div>
      </div>
    </section>'''

    return page(
        f'{e["title"]} at {v["name"]}',
        f'{e["title"]} at {v["name"]}, hosted by {h["name"]}. Free to join; estimated dining {money(e["price"])} per person paid at the venue.',
        "../", "experiences", body, og=f'assets/images/{e["cover"]}.webp',
    )


# ---------------------------------------------------------------------------
# Hosts
# ---------------------------------------------------------------------------

def build_hosts():
    cards = "".join(host_card(h, "") for h in HOSTS)
    body = f'''{page_hero(
        "Hosts",
        "Local people. Fresh food discoveries.",
        "Meet the local hosts and food creators helping you discover Karachi through its food. Explore their interests, favourite flavours, and upcoming tables to find an experience that feels right for you.",
        crumbs_html=crumbs("", [("Home", "index.html"), ("Hosts", None)]),
    )}
    <section class="section section--flush">
      <div class="container">
        <div class="host-grid host-grid--listing">{cards}</div>
        <div class="notice-card notice-card--split">
          <span class="notice-icon">{icon("users")}</span>
          <div>
            <h3>Want to host a table?</h3>
            <p>DineCircle works with creators and community hosts to plan dining experiences with Karachi venues. Hosts set the format; venues set the menu; guests join free.</p>
          </div>
          <a class="btn btn--outline" href="for-hosts.html">Become a Host</a>
        </div>
      </div>
    </section>'''
    return page(
        "Dining hosts and food creators in Karachi",
        "Meet the creators and community hosts behind DineCircle's hosted dinners, brunches and coffee meetups in Karachi.",
        "", "", body,
    )


def build_host(h):
    exp_cards = "".join(exp_card(e, "../") for e in h["experiences"])
    if not exp_cards:
        exp_cards = '<p class="muted">No upcoming experiences right now.</p>'
    interests = "".join(f'<span class="tag-pill">{esc(i)}</span>' for i in h["interests"])
    others = [x for x in HOSTS if x["slug"] != h["slug"]][:4]
    other_cards = "".join(host_card(x, "../") for x in others)

    body = f'''<div class="container detail-top">
      {crumbs("../", [("Home", "index.html"), ("Hosts", "hosts.html"), (h["name"], None)])}
    </div>
    <section class="host-head">
      <div class="container host-head__inner">
        <figure class="host-head__photo">{img("../", h["portrait"], f'{h["name"]}: {h["role"]}', eager=True)}</figure>
        <div class="host-head__body">
          <p class="eyebrow">Host profile</p>
          <h1>{esc(h["name"])}</h1>
          <p class="handle">@{esc(h["handle"])}</p>
          <p class="host-role">{esc(h["role"])} · {esc(h["city"])}</p>
          <p class="host-bio">{esc(h["bio"])}</p>
          <div class="tag-row">{interests}</div>
          <dl class="host-stats">
            <div><dt>Upcoming</dt><dd>{len(h["experiences"])}</dd></div>
            <div><dt>Hosting since</dt><dd>{h["since"]}</dd></div>
            <div><dt>Based in</dt><dd>{esc(h["city"])}</dd></div>
          </dl>
        </div>
      </div>
    </section>

    <section class="section section--flush">
      <div class="container">
        {section_head("Upcoming tables", f"Experiences hosted by {h['name']}", h["specialty"] + " around Karachi.")}
        <div class="exp-grid exp-grid--list">{exp_cards}</div>
      </div>
    </section>

    <section class="section section--cream">
      <div class="container">
        {section_head("Hosting style", "What to expect at the table", "", "")}
        <div class="style-grid">
          <div class="style-card"><span class="style-icon">{icon("users")}</span><h3>Small tables</h3><p>Seats are capped so everyone can hear the conversation, whether you arrive alone or with a friend.</p></div>
          <div class="style-card"><span class="style-icon">{icon("clock")}</span><h3>On time</h3><p>The table is held for a short window after the start time. The host meets guests at the venue entrance.</p></div>
          <div class="style-card"><span class="style-icon">{icon("check")}</span><h3>No payment at the table</h3><p>Joining is free. You settle your own food and drinks with the venue at the end of the meal.</p></div>
        </div>
        <div class="inline-cta">
          <div><h3>Host with DineCircle</h3><p>Plan a table with a Karachi restaurant and we will help with the format and listing.</p></div>
          <a class="btn btn--outline" href="../for-hosts.html">Become a Host</a>
        </div>
      </div>
    </section>

    <section class="section">
      <div class="container">
        {section_head("More hosts", "Other people to follow", "", '<a class="btn btn--outline" href="../hosts.html">Discover Hosts</a>')}
        <div class="host-grid">{other_cards}</div>
      </div>
    </section>'''

    return page(
        f'{h["name"]}: host profile',
        f'{h["name"]} hosts {h["specialty"].lower()} in Karachi. See upcoming DineCircle experiences and join free.',
        "../", "", body, og=f'assets/images/{h["portrait"]}.webp',
    )


# ---------------------------------------------------------------------------
# About & contact
# ---------------------------------------------------------------------------

def build_about():
    f = figures()

    body = f'''{page_hero(
        "About DineCircle",
        "A local guide to good food and shared tables",
        "DineCircle brings restaurants, cafés, menus, deals and hosted dining experiences into one decision, starting with Karachi. This page is who we are and what we hold ourselves to. The practical pages are linked further down.",
        crumbs_html=crumbs("", [("Home", "index.html"), ("About", None)]),
    )}
    <section class="section section--flush">
      <div class="container about-split">
        <div>
          <p class="eyebrow">Our story</p>
          <h2>A simpler way to decide where to eat</h2>
          <p class="detail-lede">Good food is part of how we know our city: a favourite café, a family dinner, a new place recommended by someone local. DineCircle helps you explore those possibilities with menus, prices, offers, and the people behind shared dining experiences.</p>
          <p>Explore places for their food and atmosphere, find value with clear prices and terms, and discover experiences with local hosts and food creators. Whether you’re revisiting a favourite or trying somewhere new, we help you make a plan with confidence.</p>
          <div class="about-actions">
            <a class="btn btn--primary" href="download.html">Download App</a>
            <a class="btn btn--outline" href="how-it-works.html">How it works</a>
          </div>
        </div>
        <figure class="about-photo">{img("", "venue_interior", "Dining room at a Karachi restaurant", eager=True)}</figure>
      </div>
    </section>

    <section class="section section--cream" id="mission">
      <div class="container about-split about-split--text">
        <div>
          <p class="eyebrow">Mission</p>
          <h2>Make the good table easy to find</h2>
          <p>Restaurants already have menus, and guests already have cravings. What is missing is the honest middle: prices you can read before you go, offers with their terms written down, and a booking that costs nothing. DineCircle exists to supply that middle, city by city.</p>
        </div>
        <div>
          <p class="eyebrow">Vision</p>
          <h2>The default way Karachi decides where to eat</h2>
          <p>Karachi first, then Lahore and Islamabad, with the same model everywhere: free for diners, a flat subscription for venues, and no commission on a booking. A dining culture this strong should not need somebody else's app to describe it.</p>
        </div>
      </div>
    </section>

    <section class="stats-band">
      <div class="container stats-grid">
        <div><strong>{f["venues"]}</strong><span>Karachi venues</span></div>
        <div><strong>{f["dishes"]}</strong><span>menu items published</span></div>
        <div><strong>{f["offers"]}</strong><span>launch offers</span></div>
        <div><strong>{f["experiences"]}</strong><span>hosted experiences</span></div>
      </div>
    </section>

    <section class="section" id="values">
      <div class="container">
        {section_head("What we stand for", "Local discovery, with care", "These are the trade-offs we have already made, written down so a partner or a guest can hold us to them.")}
        <div class="value-grid">
          <article class="value-card"><span class="style-icon">{icon("check")}</span><h3>Free for diners</h3><p>No booking fee, no subscription and no commission on your bill. If a venue charges for food, that is the only charge you see.</p></article>
          <article class="value-card"><span class="style-icon">{icon("book")}</span><h3>Useful details, clearly shared</h3><p>Explore venue menus with prices in PKR and dining offers with their terms, so you know what to expect before you go.</p></article>
          <article class="value-card"><span class="style-icon">{icon("users")}</span><h3>Rooted in local food culture</h3><p>Restaurants, cafés, hosts, and food creators bring Karachi’s food culture to life. Get to know the people and places around your next table.</p></article>
        </div>
      </div>
    </section>

    <section class="section section--cream" id="trust">
      <div class="container">
        {section_head("How we operate", "What you can rely on here",
                      "Preview content note: this site shows the Karachi pilot. Menus, prices and hours come from each venue and can change, so confirm with the restaurant before you order.")}
        <ul class="check-list">
          <li>{icon("check")} DineCircle never takes payment, holds a wallet or stores a card for a diner or a venue</li>
          <li>{icon("check")} Partners are verified before a listing is published, and a verified badge only says that review happened</li>
          <li>{icon("check")} Content follows the <a href="community-guidelines.html">community guidelines</a>, including how reports are handled</li>
          <li>{icon("check")} Personal data is handled under the <a href="privacy.html">privacy policy</a> and is never sold</li>
        </ul>
      </div>
    </section>

    <section class="section" id="explore-more">
      <div class="container">
        {section_head("Where to go next", "The pages that do the work",
                      "Contact, partner pricing, hosting and the download all have their own home now.")}
        <div class="value-grid value-grid--four">
          <article class="value-card"><span class="style-icon">{icon("search")}</span><h3>How it works</h3><p>The four steps from search to the table, and what the app adds. <a href="how-it-works.html">Read the guide</a>.</p></article>
          <article class="value-card"><span class="style-icon">{icon("book")}</span><h3>For restaurants</h3><p>What a listing gives a venue and what it costs. <a href="for-restaurants.html">See the partner page</a>.</p></article>
          <article class="value-card"><span class="style-icon">{icon("users")}</span><h3>For hosts</h3><p>Professional accounts, Host Studio and the three steps. <a href="for-hosts.html">Start hosting</a>.</p></article>
          <article class="value-card"><span class="style-icon">{icon("download")}</span><h3>Get the app</h3><p>Store listings, requirements and launch access. <a href="download.html">Download App</a>.</p></article>
        </div>
      </div>
    </section>

    {faq_section("Questions, answered", ["diner", "both"],
                 note='Anything else goes through the <a href="contact.html">contact and support page</a>.')}'''

    return page(
        "About DineCircle: our story, mission and values",
        "Who DineCircle is: a Karachi-first, free dining discovery platform for restaurants, cafés, deals and hosted experiences, with no booking fee and zero commission for partners.",
        "", "about", body,
    )


# ---------------------------------------------------------------------------
# Marketing pages
# ---------------------------------------------------------------------------

PRICE_MONTHLY = "5,000"
PRICE_YEARLY = "50,000"


def price_card(cta_label, cta_href, fine="Manual activation after payment verification. No commission on any booking."):
    return f'''<aside class="price-card">
          <p class="eyebrow eyebrow--sm">Partner plan</p>
          <p class="price-card__amount">Rs. {PRICE_MONTHLY}<span>/ month</span></p>
          <p class="price-card__alt">or Rs. {PRICE_YEARLY} per year</p>
          <hr>
          <ul class="check-list check-list--sm">
            <li>{icon("check")} Full menu and QR menu</li>
            <li>{icon("check")} Deals and redemption terms</li>
            <li>{icon("check")} Table reservations</li>
            <li>{icon("check")} Hosted experiences</li>
            <li>{icon("check")} Reviews and replies</li>
          </ul>
          <a class="btn btn--primary btn--block" href="{cta_href}">{cta_label}</a>
          <p class="aside-fine">{fine}</p>
        </aside>'''


def timeline(steps):
    """Numbered timeline used by the how-it-works, partner and host pages."""
    items = "".join(
        f'<li class="timeline__item"><span class="timeline__mark">{num}</span>'
        f'<div><h3>{title}</h3><p>{body}</p></div></li>'
        for num, title, body in steps
    )
    return f'<ol class="timeline">{items}</ol>'


# The four stages of the diner journey, in the order the scope names them.
STAGES = [
    (
        "01", "Discover", "search", "Start with the craving",
        "Search by dish, cuisine, area or price, then read the full menu with prices in PKR before you commit to a table. Nothing on DineCircle is guessed.",
        "dish_steak", "A freshly plated main course at a Karachi restaurant",
    ),
    (
        "02", "Explore", "spark", "See the terms before you go",
        "Every deal lists the discount, what it applies to and when it runs. Every venue lists its address and opening hours. You know the shape of the evening before you leave home.",
        "dish_brunch", "A brunch plate with coffee on a cafe table",
    ),
    (
        "03", "Join", "users", "Hold the table, or join a table",
        "Book a table for your own group, or join a hosted experience that still has seats. Both are free, and the venue sees your booking straight away.",
        "venue_bar", "Guests settling in at a warmly lit restaurant bar",
    ),
    (
        "04", "Dine", "check", "Show up, then settle up",
        "Show your booking or your deal at the venue. Eat what you ordered, then pay the restaurant directly. DineCircle never touches the bill and stores no card details.",
        "dish_tacos", "A plate of tacos served at the table",
    ),
]


def build_how_it_works():
    stages = ""
    for num, label, ic, title, body, image, alt in STAGES:
        stages += f'''<article class="feature-step">
          <div class="feature-step__copy">
            <p class="feature-step__label"><span>{num}</span> {label}</p>
            <h2>{title}</h2>
            <p>{body}</p>
            <p class="feature-step__icon">{icon(ic)}</p>
          </div>
          <figure class="feature-step__media">{img("", image, alt)}</figure>
        </article>'''

    body = f'''{page_hero(
        "How it works",
        "Discover. Explore. Join. Dine.",
        "Four steps from a craving to a table. No checkout, no wallet and no card on file: the app holds the booking, the restaurant holds the table, and you settle the bill at the end of the meal.",
        extra=f'''<div class="about-actions">
          <a class="btn btn--primary" href="download.html">Download App</a>
          <a class="btn btn--outline" href="restaurants.html">Browse restaurants instead</a>
        </div>''',
        crumbs_html=crumbs("", [("Home", "index.html"), ("How it works", None)]),
    )}
    <section class="section section--flush">
      <div class="container feature-timeline">{stages}</div>
    </section>

    <section class="section section--cream" id="cost">
      <div class="container">
        {section_head("What it costs", "Free for diners, always",
                      "DineCircle is paid for by partner subscriptions, not by the people eating. That is why there is no booking fee and no commission on your bill.")}
        <div class="value-grid">
          <article class="value-card"><span class="style-icon">{icon("check")}</span><h3>No booking fee</h3><p>Reserving a table costs nothing. Joining a hosted experience costs nothing. The only money that changes hands is between you and the restaurant.</p></article>
          <article class="value-card"><span class="style-icon">{icon("book")}</span><h3>No in-app payment</h3><p>There is no wallet, no stored card and no checkout. You pay the venue the way you always have, at the table.</p></article>
          <article class="value-card"><span class="style-icon">{icon("verified")}</span><h3>No commission on the bill</h3><p>A venue that takes your booking keeps the whole bill. DineCircle charges partners a flat subscription instead.</p></article>
        </div>
      </div>
    </section>

    <section class="section" id="app-adds">
      <div class="container about-split">
        <div>
          <p class="eyebrow">Why the app</p>
          <h2>The website shows you the city. The app holds your place in it.</h2>
          <p class="detail-lede">This site is for browsing: menus, prices, deals, venues and hosts. Anything that needs your account happens in the DineCircle app on your phone.</p>
          <ul class="check-list">
            <li>{icon("calendar")} Table bookings with confirmation from the venue</li>
            <li>{icon("users")} Experience seats, with seats remaining shown before you join</li>
            <li>{icon("spark")} Deal codes kept in one place instead of screenshotted</li>
            <li>{icon("pin")} Saved places and your own booking history</li>
          </ul>
          <div class="about-actions"><a class="btn btn--primary" href="download.html">Download App</a></div>
        </div>
        <figure class="about-photo">{app_phone_crop("app_home", "The home screen of the DineCircle app")}</figure>
      </div>
    </section>

    {faq_section("Booking questions", ["diner"], note='Everything else lives on the <a href="contact.html">contact page</a>.', limit=4)}

    {cta_band("A table is four taps away",
              "Get the app and hold your next table.",
              "Free for diners, free to book, and no commission on what you order.",
              '<a class="btn btn--light" href="download.html">Download App</a>',
              '<a class="btn btn--ghost-light" href="for-restaurants.html">For Restaurants</a>')}'''

    return page(
        "How DineCircle works: Discover, Explore, Join, Dine",
        "Four steps from search to table. See how DineCircle works for diners: browse menus and deals for free, join a hosted experience, and pay the restaurant directly with no commission.",
        "", "how", body,
    )


def build_for_restaurants():
    body = f'''{page_hero(
        "For restaurants and cafés",
        "Put your full menu on the map",
        "DineCircle puts your menu, your deals and your tables in front of diners who are deciding where to eat tonight. A flat subscription, zero booking commission and no payment gateway to set up.",
        extra='''<div class="about-actions">
          <a class="btn btn--primary" href="become-a-partner.html">Become a Partner</a>
          <a class="btn btn--outline" href="#pricing">See the pricing</a>
        </div>''',
        crumbs_html=crumbs("", [("Home", "index.html"), ("For restaurants", None)]),
    )}
    <section class="section section--flush">
      <div class="container about-split">
        <div>
          <p class="eyebrow">What you get</p>
          <h2>A listing diners can act on</h2>
          <p class="detail-lede">Guests do not need another account to see your food. Your menu, prices and hours are public, indexed, and open on any phone.</p>
          <ul class="check-list">
            <li>{icon("book")} <strong>Publish your full menu</strong> with sections, descriptions and prices in PKR</li>
            <li>{icon("device")} <strong>Print the QR menu</strong> we generate for your table cards and windows</li>
            <li>{icon("spark")} <strong>Run deals with terms</strong> that guests read before they order</li>
            <li>{icon("calendar")} <strong>Take table reservations</strong> from the DineCircle app</li>
            <li>{icon("users")} <strong>Host experiences</strong> with local hosts and food creators</li>
            <li>{icon("quote")} <strong>Reply to reviews</strong> so the answer sits next to the feedback</li>
          </ul>
        </div>
        <figure class="about-photo">{img("", "venue_interior", "Dining room at a Karachi restaurant")}</figure>
      </div>
    </section>

    <section class="section section--cream" id="pricing">
      <div class="container partner-panel">
        <div class="partner-copy">
          <p class="eyebrow">What it costs</p>
          <h2>One subscription, no commission</h2>
          <p>A partner subscription covers your listing, your QR menu, your deals, your reservations and your hosted experiences. We do not take a cut of any booking, so a full room never costs you more than the plan.</p>
          <ul class="check-list">
            <li>{icon("check")} PKR {PRICE_MONTHLY} per month or PKR {PRICE_YEARLY} per year</li>
            <li>{icon("check")} 0% booking commission, on any booking size</li>
            <li>{icon("check")} No payment gateway, no payout account and no settlement cycle</li>
            <li>{icon("check")} Pay by bank transfer, JazzCash or Easypaisa</li>
          </ul>
        </div>
        {price_card("Start your application", "become-a-partner.html")}
      </div>
    </section>

    <section class="section" id="activation">
      <div class="container">
        {section_head("Activation", "From application to live listing",
                      "Four steps, and a real person verifies the payment at the end of them. There is no self-serve activation, because there is no online card payment.")}
        {timeline([
            ("01", "Apply", "Send the venue name, the area and a contact who can answer questions about the menu. It takes about two minutes."),
            ("02", "Verify", "We confirm the venue, the menu and who is authorised to represent it. If something is unclear we reply with a question rather than moving on."),
            ("03", "Activate", "Send the subscription by bank transfer, JazzCash or Easypaisa. Your account is switched to active once the payment is verified."),
            ("04", "Publish", "Your menu, QR code, deals and reservation settings go live. Updates after that are yours to make from the Partner app."),
        ])}
      </div>
    </section>

    <section class="section section--cream" id="not-included">
      <div class="container">
        {section_head("What we do not do", "Clear boundaries, on purpose",
                      "DineCircle is a discovery and booking platform. It is not a delivery service and not a point-of-sale system, so it will not ask to sit inside your operation.")}
        <div class="value-grid">
          <article class="value-card"><span class="style-icon">{icon("close")}</span><h3>No online ordering</h3><p>Guests order at the table, in your restaurant, the way your kitchen already works.</p></article>
          <article class="value-card"><span class="style-icon">{icon("close")}</span><h3>No payments taken</h3><p>Bills are settled between the guest and the venue. DineCircle does not process or hold guest money.</p></article>
          <article class="value-card"><span class="style-icon">{icon("close")}</span><h3>No POS integration</h3><p>No new hardware, no till replacement and no training day for your floor team.</p></article>
        </div>
      </div>
    </section>

    {faq_section("Partner questions", ["partner"], note='Prefer to write first? Email <a href="mailto:' + PARTNER_EMAIL + '">' + PARTNER_EMAIL + '</a>.')}

    {cta_band("Partner with DineCircle",
              "Your menu in front of people deciding where to eat.",
              "Send the application and we will reply with the next step inside one working day.",
              '<a class="btn btn--light" href="become-a-partner.html">Become a Partner</a>',
              '<a class="btn btn--ghost-light" href="restaurants.html">See a live listing</a>')}'''

    return page(
        "For restaurants and cafés in Karachi | DineCircle",
        "List your restaurant on DineCircle: full menu and QR menu, deals with terms, table reservations and hosted experiences. PKR 5,000 per month with 0% booking commission.",
        "", "for-restaurants",
        body, og="assets/images/venue_interior.webp",
    )


# ---------------------------------------------------------------------------
# Marketing pages, continued
# ---------------------------------------------------------------------------

VENUE_TYPES = [
    ("restaurant", "Restaurant"),
    ("cafe", "Café"),
    ("bakery", "Bakery or dessert spot"),
    ("fast-casual", "Fast casual"),
    ("hotel", "Hotel dining"),
    ("other", "Something else"),
]

PARTNER_AREAS = [
    "DHA Phase 5", "DHA Phase 6", "DHA Phase 8", "Clifton", "Boat Basin",
    "Zamzama", "Karsada", "Bahadurabad", "Gulshan", "Another area in Karachi",
    "Outside Karachi",
]


def build_become_a_partner():
    cuisine_options = [("", "Cuisine (optional)")] + [(c.lower(), c) for c in CUISINES]
    fields = (
        '<div class="form-grid">'
        + field("Venue name", "venueName", required=True, placeholder="Example: Kolachi Restaurant")
        + field("Your name", "name", required=True, placeholder="First and last name", autocomplete="name")
        + field("Email", "email", kind="email", required=True, placeholder="you@venue.pk", autocomplete="email")
        + field("Phone", "phone", kind="tel", required=True, placeholder="+92 3XX XXXXXXX", autocomplete="tel")
        + field("Area", "city", options=[("", "Select the area")] + [(a, a) for a in PARTNER_AREAS], required=True)
        + field("Venue type", "venueType", options=[("", "Select the type")] + VENUE_TYPES, required=True)
        + field("Main cuisine", "cuisine", options=cuisine_options)
        + field("Seats or size", "seats", placeholder="Roughly how many covers")
        + field("Website or Instagram", "website_handle", placeholder="Optional, helps us find you")
        + field("Anything we should know?", "message", rows=4, wide=True,
                placeholder="Opening hours, parking, an offer you want to run, or who signs off the listing")
        + '''<label class="field field--check field--wide">
            <input type="checkbox" name="consent" value="yes" required>
            <span>I am authorised to list this venue and agree to be contacted about a DineCircle partnership.</span>
          </label>'''
        + '</div>'
    )

    body = f'''{page_hero(
        "Become a partner",
        "List your venue on DineCircle",
        "Tell us about the venue and we will reply inside one working day with the next step. There is no fee to apply, no card to add and no commission on any booking.",
        extra='''<p class="page-hero__assurance">Applications are read by a person, not a queue. Average first reply: one working day.</p>''',
        crumbs_html=crumbs("", [("Home", "index.html"), ("For restaurants", "for-restaurants.html"), ("Become a Partner", None)]),
    )}
    <section class="section section--flush">
      <div class="container">
        {section_head("Eligibility", "Before you start")}
        <div class="value-grid value-grid--four">
          <article class="value-card"><span class="style-icon">{icon("pin")}</span><h3>A physical venue</h3><p>A restaurant, café, bakery or hotel dining room guests can sit down in, in or around Karachi.</p></article>
          <article class="value-card"><span class="style-icon">{icon("book")}</span><h3>A menu you can share</h3><p>Dish names and prices in PKR that you are happy to publish. We build the page from what you send.</p></article>
          <article class="value-card"><span class="style-icon">{icon("check")}</span><h3>A decision maker</h3><p>The person who can confirm prices, approve a deal and answer a verification question.</p></article>
          <article class="value-card"><span class="style-icon">{icon("users")}</span><h3>Room to hold tables</h3><p>You take reservations at the table. DineCircle sends the guest; you keep the seating.</p></article>
        </div>
      </div>
    </section>

    <section class="section section--cream" id="apply">
      <div class="container contact-layout">
        <div class="contact-copy">
          <p class="eyebrow">Application</p>
          <h2>Ten fields, about two minutes</h2>
          <p>Send this and the partner team picks it up. If the venue is not a fit for the pilot we will still answer, and we will tell you why.</p>
          <ul class="contact-list">
            <li><span class="contact-icon">{icon("clock")}</span><div><strong>Response time</strong><span>One working day</span></div></li>
            <li><span class="contact-icon">{icon("mail")}</span><div><strong>Prefer email?</strong><a href="mailto:{PARTNER_EMAIL}?subject=Partnership%20application">{PARTNER_EMAIL}</a></div></li>
            <li><span class="contact-icon">{icon("verified")}</span><div><strong>Cost to apply</strong><span>Nothing. The subscription starts only after activation.</span></div></li>
          </ul>
          <p class="form-note">We use these details only to evaluate and set up the listing. Read the <a href="privacy.html">privacy policy</a>.</p>
        </div>
        {lead_form(
            "partner_application",
            fields,
            "Submit application",
            'Sent straight to the DineCircle partner team. Something wrong? Email <a href="mailto:' + PARTNER_EMAIL + '">' + PARTNER_EMAIL + '</a> instead.',
            cls="contact-form lead-form--partner",
        )}
      </div>
    </section>

    <section class="section" id="timeline">
      <div class="container">
        {section_head("What happens next", "Apply. Verify. Activate. Publish.",
                      "Four steps between this form and a live listing. Nothing is charged before you see your own page.")}
        {timeline([
            ("01", "Apply", "Send the form above. We read it and come back with questions about the menu, the hours and who represents the venue."),
            ("02", "Verify", "We confirm the venue and agree the listing content: sections, prices, photographs you own, and the deals you want to run."),
            ("03", "Activate", "Choose monthly or yearly and pay by bank transfer, JazzCash or Easypaisa. The account is switched to active once the payment is verified."),
            ("04", "Publish", "Your page, your QR menu and your reservation settings go live. You manage them from the DineCircle Partner app."),
        ])}
      </div>
    </section>

    <section class="section section--cream" id="pricing">
      <div class="container partner-panel">
        <div class="partner-copy">
          <p class="eyebrow">Pricing recap</p>
          <h2>Flat subscription, zero commission</h2>
          <p>One plan covers the listing, the QR menu, deals, reservations and hosted experiences. Payment is manual after verification, because DineCircle does not take card details from venues or guests.</p>
          <ul class="check-list">
            <li>{icon("check")} PKR {PRICE_MONTHLY} per month, or PKR {PRICE_YEARLY} per year</li>
            <li>{icon("check")} 0% commission on every booking, at any cover count</li>
            <li>{icon("check")} No gateway, no payout account, no settlement wait</li>
            <li>{icon("check")} Cancel by email before the next term; the listing stays until the term ends</li>
          </ul>
          <div class="about-actions"><a class="btn btn--outline" href="for-restaurants.html">Read the full partner page</a></div>
        </div>
        {price_card("Email the partner team", "mailto:" + PARTNER_EMAIL + "?subject=DineCircle%20partner%20enquiry")}
      </div>
    </section>

    {faq_section("Owner questions", ["partner"], note='Not covered here? <a href="contact.html">Contact and support</a> routes your question to the right team.')}

    {cta_band("Ready when you are",
              "Send the application and we take it from there.",
              "One working day for a first reply, and no cost until the listing is activated.",
              '<a class="btn btn--light" href="#apply">Start your application</a>',
              '<a class="btn btn--ghost-light" href="for-restaurants.html">How partnership works</a>')}'''

    return page(
        "Become a DineCircle partner: list your restaurant in Karachi",
        "Apply to list your restaurant or café on DineCircle. PKR 5,000 per month or PKR 50,000 per year, 0% booking commission, no payment gateway, manual activation.",
        "", "for-restaurants",
        body, og="assets/images/venue_interior.webp",
    )


def build_for_hosts():
    sample = exp_card(EXPERIENCES[0], "")
    body = f'''{page_hero(
        "For hosts and creators",
        "Turn what you know about food into a table",
        "Hosts plan the evening: the venue, the menu, who comes and how the table runs. DineCircle brings the guests and holds the seats. Host accounts are free, and everything is planned inside the app.",
        extra='''<div class="about-actions">
          <a class="btn btn--primary" href="download.html">Get the app</a>
          <a class="btn btn--outline" href="#become">See the three steps</a>
        </div>''',
        crumbs_html=crumbs("", [("Home", "index.html"), ("For hosts", None)]),
    )}
    <section class="section section--flush">
      <div class="container about-split">
        <div>
          <p class="eyebrow">What a host does</p>
          <h2>You bring the people. We bring the seats.</h2>
          <p class="detail-lede">A host is a food creator, a critic, a community organiser or simply the person everyone asks where to eat. You choose the format; the venue serves the meal.</p>
          <ul class="check-list">
            <li>{icon("calendar")} <strong>Plan the experience</strong>: date, time, seats, menu style and what the evening is about</li>
            <li>{icon("users")} <strong>Set who it is for</strong>: a first-in-city crowd, a brunch regulars table, a grill night</li>
            <li>{icon("book")} <strong>Track seats</strong> from Host Studio, so you always know how full the table is</li>
            <li>{icon("quote")} <strong>Meet your guests</strong> at the venue on the night and run the room</li>
          </ul>
        </div>
        <figure class="about-photo">{img("", "portrait_2", "A DineCircle host welcoming guests at a shared table")}</figure>
      </div>
    </section>

    <section class="section section--cream" id="become">
      <div class="container">
        {section_head("Getting started", "Three steps, and no approval queue",
                      "Hosting is self-service inside the app. There is no application form, no interview and no fee, because the experience is booked and served by the venue.")}
        {steps_four([
            ("01", "download", "Get the app", "Download DineCircle and create your account. It is the same app diners use, so your bookings and your hosted tables live in one place."),
            ("02", "users", "Switch to Professional", "In account settings, change your account type to Professional. That promotes you to host and unlocks Host Studio on the same sign-in."),
            ("03", "calendar", "Plan and publish", "In Host Studio, set the venue, the date, the seats and the format, then publish. Guests join free and pay the venue for their own meal."),
        ])}
        <p class="section-note">Switching back to a personal account is available whenever you have no upcoming experience still on the calendar, so guests are never left holding a seat that no longer exists.</p>
      </div>
    </section>

    <section class="section" id="example">
      <div class="container">
        {section_head("An example", "What a published experience looks like",
                      "This is a live experience from the Karachi pilot, exactly as a host publishes it and as a diner sees it.",
                      '<a class="btn btn--outline" href="experiences.html">Join Experience</a>')}
        <div class="exp-grid">{sample}</div>
      </div>
    </section>

    <section class="section section--cream" id="safety">
      <div class="container">
        {section_head("Community and safety", "Hosted tables carry a responsibility", "Guests are meeting people their own table recommended them. These are the notes we ask every host to keep to.")}
        <div class="value-grid">
          <article class="value-card"><span class="style-icon">{icon("users")}</span><h3>Be honest about the format</h3><p>Say who the table is for and what happens on the night. A guest who arrives expecting a quiet dinner to a loud grill night did not choose wrong.</p></article>
          <article class="value-card"><span class="style-icon">{icon("check")}</span><h3>Confirm with the venue</h3><p>Agree the menu, the seating and the cancellation terms with the restaurant before you publish. The venue is the host of the room; you are the host of the table.</p></article>
          <article class="value-card"><span class="style-icon">{icon("verified")}</span><h3>Respect the guests</h3><p>No pressure to buy anything, no recruitment from the table, and no sharing a guest contact with anyone. Report a problem and the listing is reviewed.</p></article>
        </div>
        <p class="section-note">Full expectations live in the <a href="community-guidelines.html">community guidelines</a>.</p>
      </div>
    </section>

    {faq_section("Host questions", ["host"], note='Still unsure? <a href="contact.html">Ask the team</a> before you publish anything.')}

    {cta_band("Bring your table",
              "Open Host Studio and plan your first experience.",
              "Free host accounts, no approval queue, and guests who pay the venue directly.",
              '<a class="btn btn--light" href="download.html">Get the app</a>',
              '<a class="btn btn--ghost-light" href="hosts.html">Meet the current hosts</a>')}'''

    return page(
        "Become a DineCircle host: run a dining experience",
        "Host a dinner, brunch or coffee meetup on DineCircle. Free host accounts, a self-service switch to a Professional account, and Host Studio inside the app to plan and publish.",
        "", "for-hosts",
        body, og="assets/images/hero_tasting.webp",
    )


# ---------------------------------------------------------------------------
# Legal pages
# ---------------------------------------------------------------------------

def pending_platforms():
    """Stores with no listing URL yet. Drives both the badge state and the
    notify-me block, so the two can never disagree."""
    return [p for p in ("android", "ios") if not STORE_LINKS.get(p)]


def requirements_grid():
    cells = ""
    for platform in ("android", "ios"):
        store, os_name, requirement = STORE_META[platform]
        state = f'Listed on the {store}' if STORE_LINKS.get(platform) else f'{store} listing opens with the next release'
        cells += f'''<div class="requirement">
            <p class="requirement__os">{os_name}</p>
            <p class="requirement__need">{requirement}</p>
            <p class="requirement__store">{state}</p>
          </div>'''
    return f'<div class="requirement-grid">{cells}</div>'


def notify_block():
    pending = pending_platforms()
    if not pending:
        return ""
    options = [("", "Which store are you waiting for?")] + [(p, STORE_META[p][0]) for p in pending]
    fields = ('<div class="form-grid form-grid--two">'
              + field("Email", "email", kind="email", required=True, placeholder="you@example.com", autocomplete="email")
              + field("Send me the invite for", "platform", options=options, required=True)
              + '</div>')
    return f'''<div class="notify-card" data-notify>
          <p class="eyebrow">Not on your store yet</p>
          <h3>Leave your email and we will send your invite first</h3>
          <p>DineCircle is opening in phases across Karachi. Invites go out in the order they arrive, and we only email about the launch.</p>
          {lead_form("waitlist", fields, "Notify me", "We store this email only to send the launch invite. See the <a href=\"privacy.html\">privacy policy</a>.", cls="notify-form")}
        </div>'''


def build_download():
    pending = pending_platforms()
    live = [STORE_META[p][0] for p in ("android", "ios") if STORE_LINKS.get(p)]
    if not pending:
        availability = "The app is live on " + " and ".join(live) + "."
    else:
        availability = ("DineCircle is in its Karachi launch window, so the store listings are being published in phases. "
                        "The buttons below flip to live the moment a store clears review, with no rebuild of this page.")
    body = f'''{page_hero(
        "Download the app",
        "Great food, in your pocket",
        "Menus, deals, table bookings and hosted experiences in one free app. No wallet, no card on file and no commission on what you order.",
        extra=f'''<div class="download-hero__actions">{store_row()}</div>
        <p class="page-hero__assurance">{availability}</p>''',
        crumbs_html=crumbs("", [("Home", "index.html"), ("Download App", None)]),
    )}
    <section class="section section--flush" id="screens">
      <div class="container">
        {section_head("Inside the app", "Four taps from a craving to a booked table",
                      "Real screens from the shipping Customer App, not mockups. Tap through the same flow your first booking takes.")}
        {app_stage()}
      </div>
    </section>

    <section class="section section--cream" id="qr">
      <div class="container host-panel">
        <div>
          <p class="eyebrow">Scan it on your phone</p>
          <h2>Point a camera here, land on the store page</h2>
          <p>The QR code encodes this page at <strong>{esc(qr_target())}</strong>, so it works from a poster, a table card or a friend's screen. Scanning it takes you to the store listing as soon as your platform is live, and to this page with the invite form until then.</p>
          <ul class="check-list">
            <li>{icon("device")} Android 7.0 or later, iOS 15 or later</li>
            <li>{icon("check")} Free to download and free to book</li>
            <li>{icon("users")} Same account for table bookings and hosted experiences</li>
          </ul>
        </div>
        {qr_block()}
      </div>
    </section>

    <section class="section" id="requirements">
      <div class="container">
        {section_head("Requirements", "What you need, stated plainly", "No account is needed to browse this website. The app is where bookings and experience seats happen.")}
        {requirements_grid()}
      </div>
    </section>

    <section class="section section--cream" id="why-app">
      <div class="container">
        {section_head("What the app adds", "The parts that need your account", "This website is for discovery. Anything that holds a table for you lives on your phone.")}
        <div class="value-grid">
          <article class="value-card"><span class="style-icon">{icon("calendar")}</span><h3>Table bookings</h3><p>Reserve a table and get the venue's confirmation in the app. Free, with no card details stored.</p></article>
          <article class="value-card"><span class="style-icon">{icon("spark")}</span><h3>Deal codes</h3><p>Every offer you are holding, with its terms and its code, in one place instead of in screenshots.</p></article>
          <article class="value-card"><span class="style-icon">{icon("users")}</span><h3>Experience seats</h3><p>Join a hosted dinner or brunch while seats are left, and see the estimate you will pay the venue.</p></article>
          <article class="value-card"><span class="style-icon">{icon("pin")}</span><h3>Saved places</h3><p>Keep the venues worth going back to, and pick up where your last search stopped.</p></article>
        </div>
      </div>
    </section>

    <section class="section" id="notify">
      <div class="container contact-layout">
        <div class="contact-copy">
          <p class="eyebrow">Launch access</p>
          <h2>Opening in phases across Karachi</h2>
          <p>DineCircle is rolling out venue by venue, and the store listings go live with that rollout rather than all at once. If your platform is not listed yet, leave your email and we will send your invite as soon as it is available.</p>
          <ul class="contact-list">
            <li><span class="contact-icon">{icon("mail")}</span><div><strong>General</strong><a href="mailto:{EMAIL}">{EMAIL}</a></div></li>
            <li><span class="contact-icon">{icon("verified")}</span><div><strong>Support</strong><a href="mailto:{SUPPORT_EMAIL}">{SUPPORT_EMAIL}</a></div></li>
            <li><span class="contact-icon">{icon("clock")}</span><div><strong>Support hours</strong><span>{SUPPORT_HOURS}</span></div></li>
          </ul>
        </div>
        {notify_block() or '<div class="notice-card"><p class="notice-title">Both store listings are live</p><p>Use the buttons at the top of this page. No invite list is needed.</p></div>'}
      </div>
    </section>

    {cta_band("No table without the food",
              "Download DineCircle and find your next favourite.",
              "Free for diners, no booking fee, and you pay the restaurant directly.",
              '<a class="btn btn--light" href="#screens">See the app first</a>',
              '<a class="btn btn--ghost-light" href="how-it-works.html">How it works</a>')}'''

    return page(
        "Download the DineCircle app for Android and iPhone",
        "Get the DineCircle app: free table bookings, dining deals with clear terms and hosted food experiences in Karachi. Android and iOS, no commission and no in-app payment.",
        "", "",
        body, og="assets/images/app_home.webp",
    )


def build_contact():
    topics = [
        ("booking", "A table booking or a reservation"),
        ("deal", "A deal or an offer"),
        ("experience", "An experience or a host"),
        ("partner", "Partnering with DineCircle"),
        ("press", "Press and media"),
        ("privacy", "Privacy or my account"),
        ("other", "Something else"),
    ]
    fields = ('<div class="form-grid form-grid--two">'
              + field("Your name", "name", required=True, placeholder="First and last name", autocomplete="name")
              + field("Email", "email", kind="email", required=True, placeholder="you@example.com", autocomplete="email")
              + field("Phone (optional)", "phone", kind="tel", placeholder="Only if you want a call back", autocomplete="tel")
              + field("What is this about?", "topic", options=topics, wide=False)
              + field("Message", "message", rows=6, wide=True, placeholder="Tell us what you need. Venue and booking reference help us answer faster.")
              + '</div>')

    routes = [
        ("users", "Diners and bookings", f'<a href="mailto:{SUPPORT_EMAIL}">{SUPPORT_EMAIL}</a>', "A booking that did not confirm, a table the venue cannot find, or a deal that was not applied to your bill."),
        ("verified", "Restaurants and cafés", f'<a href="mailto:{PARTNER_EMAIL}">{PARTNER_EMAIL}</a>', "Listings, subscription questions and activation status. <a href=\"become-a-partner.html\">Apply here</a> to start."),
        ("calendar", "Hosts and creators", '<a href="mailto:' + EMAIL + '">' + EMAIL + '</a>', "Host Studio, changing a published experience, or planning one with a venue."),
        ("quote", "Press and partnerships", "<a href=\"#contact-form\">Use the form</a> and choose Press and media", "Interviews, launch coverage and city expansion conversations."),
        ("mail", "Privacy and your account", f'<a href="mailto:{EMAIL}">{EMAIL}</a>', "Access, correction or deletion requests. Read the <a href=\"privacy.html\">privacy policy</a> first."),
    ]
    route_rows = "".join(
        f'<li><span class="contact-icon">{icon(ic)}</span><div><strong>{title}</strong><p>{where}</p><p class="route-note">{note}</p></div></li>'
        for ic, title, where, note in routes
    )

    body = f'''{page_hero(
        "Contact and support",
        "Talk to a person at DineCircle",
        "One route for every question: a booking, a deal, a venue, an experience or a partnership. Support runs " + SUPPORT_HOURS + ", and we reply within one working day.",
        crumbs_html=crumbs("", [("Home", "index.html"), ("Contact", None)]),
    )}
    <section class="section section--flush" id="contact-form">
      <div class="container contact-layout">
        <div class="contact-copy">
          <p class="eyebrow">Send a message</p>
          <h2>Tell us what happened</h2>
          <p>The form goes to the team that can act on it. If it is about a booking, include the venue name and the date so we do not have to ask.</p>
          <ul class="contact-list">
            <li><span class="contact-icon">{icon("mail")}</span><div><strong>General</strong><a href="mailto:{EMAIL}">{EMAIL}</a></div></li>
            <li><span class="contact-icon">{icon("verified")}</span><div><strong>Diner support</strong><a href="mailto:{SUPPORT_EMAIL}">{SUPPORT_EMAIL}</a></div></li>
            <li><span class="contact-icon">{icon("users")}</span><div><strong>Partners</strong><a href="mailto:{PARTNER_EMAIL}">{PARTNER_EMAIL}</a></div></li>
            <li><span class="contact-icon">{icon("pin")}</span><div><strong>Based in</strong><span>{LOCATION}</span></div></li>
            <li><span class="contact-icon">{icon("clock")}</span><div><strong>Support hours</strong><span>{SUPPORT_HOURS}</span></div></li>
          </ul>
        </div>
        {lead_form(
            "contact",
            fields,
            "Send message",
            'We use this to reply to you and nothing else. Account and data requests are handled under the <a href="privacy.html">privacy policy</a>.',
            cls="contact-form lead-form--contact",
        )}
      </div>
    </section>

    <section class="section section--cream" id="routing">
      <div class="container">
        {section_head("Where each question goes", "Skip the queue", "If you would rather write directly, every team has its own address. The form above reaches the same people.")}
        <ul class="contact-list contact-list--full">{route_rows}</ul>
      </div>
    </section>

    <section class="section" id="before-you-write">
      <div class="container">
        {section_head("Before you write", "Answers that are usually faster", "Most questions we receive are already answered on the FAQ and support pages.")}
        <div class="value-grid value-grid--four">
          <article class="value-card"><span class="style-icon">{icon("check")}</span><h3>Is it free?</h3><p>Yes. Browsing, booking and joining cost nothing, and DineCircle takes no commission on your bill. <a href="how-it-works.html">How it works</a>.</p></article>
          <article class="value-card"><span class="style-icon">{icon("spark")}</span><h3>How do deals work?</h3><p>Show the offer at the venue before ordering and they apply it. <a href="deals.html">Browse deals</a>.</p></article>
          <article class="value-card"><span class="style-icon">{icon("device")}</span><h3>Where is my booking?</h3><p>Bookings live in the app, not on this website. <a href="download.html">Download App</a>.</p></article>
          <article class="value-card"><span class="style-icon">{icon("verified")}</span><h3>Want to list a venue?</h3><p>Start with the application. <a href="become-a-partner.html">Become a Partner</a>.</p></article>
        </div>
      </div>
    </section>

    {faq_section("Support questions", ["diner", "both"], note='Anything else? The <a href="about.html">about page</a> explains who we are.')}

    {cta_band("Still deciding?",
              "Get the app and see for yourself.",
              "Free to download, free to book, and nothing to pay us at any point.",
              '<a class="btn btn--light" href="download.html">Download App</a>',
              '<a class="btn btn--ghost-light" href="community-guidelines.html">Community guidelines</a>')}'''

    return page(
        "Contact and support | DineCircle",
        "Contact DineCircle for bookings, deals, venues, hosts, press and privacy. Support hours, the right address for every question, and a form that reaches the team.",
        "", "",
        body,
    )


def build_community_guidelines():
    sections = [
        ("who", "Who these guidelines apply to", '''<p>These guidelines apply to everyone who uses DineCircle: diners browsing this website, guests who join a hosted experience, hosts and food creators who publish one, and the venues that publish menus, prices and offers. They apply to content you publish on DineCircle and to conduct at the table.</p><p>They are not a legal contract. Where they and the <a href="terms.html">terms of service</a> differ, the terms govern.</p>'''),
        ("hosting", "Hosting and attending with respect", '''<p>A host sets the tone of a table. Guests choose it expecting what the listing described, so publish an honest description of the format, the crowd and what happens on the night.</p><ul><li>Describe the experience as it will actually run, including whether it is a group table or a shared seating format.</li><li>No pressure to buy anything, recruit for anything, or take part in anything beyond the meal.</li><li>Contact details of guests belong to those guests. Do not collect, share or sell them.</li><li>Treat venue staff as partners, not service to be directed. The venue owns the room.</li></ul><p>Guests have a matching duty: arrive roughly when you said you would, tell the host early if you cannot come so the seat can go to someone else, and behave towards the other people at the table the way you would want a stranger to behave towards you.</p>'''),
        ("listings", "Venue listings and content", '''<p>Partners publish their own information, and diners rely on it when deciding where to spend an evening.</p><ul><li>Menus, prices, opening hours and amenities must be current and must be yours to publish.</li><li>Photographs must show the actual food, room or team, not stock imagery standing in for it.</li><li>Deal terms must state what the offer applies to, when it runs and what it cannot be combined with.</li><li>A verified badge means we reviewed the partnership details. It is not a quality rating and we do not adjust it for a subscription size.</li></ul>'''),
        ("reviews", "Reviews, and no manipulation", '''<p>Reviews are most useful when they are honest and specific.</p><ul><li>Only review somewhere you actually ate or joined.</li><li>No paid, swapped, bulk or competitor-suppressed reviews, and no reviews of your own venue written as a guest.</li><li>No personal attacks, slurs or published contact details of staff or guests. Criticise the meal and the service, not the person.</li><li>Hosts and venues may reply. A reply is welcome; removing or reporting an honest review to make it disappear is not.</li></ul>'''),
        ("safety", "Experience safety and cancellation etiquette", '''<p>DineCircle does not take payment, so the money relationship is always between a guest and a venue. Nothing on this platform is a promise of money back, and no host should present it as one.</p><ul><li>Agree the menu, the seating and the cancellation notice with the venue before you publish.</li><li>If a date or a format has to move, tell joined guests as early as you can rather than at the door.</li><li>A guest who cancels late takes a seat someone else could have had. Tell the host, do not simply not turn up.</li><li>Anything that feels unsafe is not a community question. Contact the relevant authorities first, then tell us so we can act on the listing.</li></ul>'''),
        ("enforcement", "Reporting and how we act", f'''<p>Report a listing, a review or a host by emailing <a href="mailto:{SUPPORT_EMAIL}">{SUPPORT_EMAIL}</a> with the link to the page and what happened. Reports are read by a person, and we keep the reporter's details out of any message to the other side.</p><p>We act in steps, and the step depends on the finding rather than on how many times a page has been reported:</p><ol><li><strong>A conversation.</strong> For unclear or first-time content, we contact the person who published it and ask for a change.</li><li><strong>Content hidden or edited.</strong> A review, a listing claim or a photo that breaks these guidelines can be unpublished while it is fixed.</li><li><strong>Access limited.</strong> Repeated or deliberate abuse can cost the ability to post reviews, publish listings or host experiences.</li><li><strong>Accounts closed.</strong> Fake listings, review manipulation, harvesting guest contact details, or conduct that puts guests or staff at risk ends the account. Where a subscription is paid, closure for these reasons does not create a refund.</li></ol><p>Partners can ask us to review a decision, and we will explain the finding. Venues that repeatedly publish prices or hours that do not match the table lose the listing rather than keep editing it.</p>'''),
    ]
    return legal_page(
        "Community Guidelines",
        "How DineCircle expects hosts, guests, venues and reviewers to behave: hosted tables, listing accuracy, honest reviews, safety and how reports are handled.",
        "DineCircle is built around a table with strangers at it. These guidelines exist so the person booking from a phone can trust the room they arrive in.",
        sections,
        related='<p class="prose-note">Also read the <a href="for-hosts.html">host guide</a>, the <a href="terms.html">terms of service</a> and the <a href="privacy.html">privacy policy</a>.</p>',
    )


def legal_page(title, description, intro, sections, related=""):
    toc = "".join(f'<a href="#{sid}">{esc(heading)}</a>' for sid, heading, _ in sections)
    content = "".join(
        f'<section class="legal-section" id="{sid}"><h2>{esc(heading)}</h2>{body}</section>'
        for sid, heading, body in sections
    )
    body = f'''{page_hero(
        "Legal",
        title,
        intro,
        crumbs_html=crumbs("", [("Home", "index.html"), (title, None)]),
    )}
    <section class="section section--flush">
      <div class="container legal-layout">
        <aside class="legal-toc">
          <p class="eyebrow eyebrow--sm">On this page</p>
          <nav aria-label="Sections">{toc}</nav>
          <p class="legal-meta">Effective {EFFECTIVE}</p>
        </aside>
        <div class="prose">
          {content}
          {related}
          <p class="prose-note">Questions about this page? Email <a href="mailto:{EMAIL}">{EMAIL}</a>.</p>
        </div>
      </div>
    </section>'''
    return page(title, description, "", "", body)


def build_privacy():
    sections = [
        ("who-we-are", "Who we are", f'''<p>DineCircle is a restaurant discovery platform based in Karachi, Pakistan. This policy explains how we handle personal information on the DineCircle website and in the DineCircle customer and partner apps.</p><p>For privacy questions, contact <a href="mailto:{EMAIL}">{EMAIL}</a>.</p>'''),
        ("information-we-collect", "Information we collect", '''<p>We collect only what we need to run the service:</p><ul><li><strong>Account details</strong> you provide in the app, such as your name, email address and phone number.</li><li><strong>Booking and experience details</strong>, including the venue, date, party size and any dietary notes you choose to share.</li><li><strong>Deal redemptions</strong> recorded when a venue applies an offer.</li><li><strong>Support messages</strong> you send to us.</li><li><strong>Website form submissions</strong>, kept so an enquiry can be answered and tracked. A partner application stores the venue name, your contact name, email, phone, area and your message. A launch-invite entry stores your email and the platform you chose.</li><li><strong>Technical information</strong> such as device type, browser, approximate location derived from your IP address, and pages viewed.</li></ul><p>This marketing website does not create accounts and does not process payments.</p>'''),
        ("how-we-use-it", "How we use information", '''<p>We use information to:</p><ul><li>Create and secure your account and confirm bookings or experience seats.</li><li>Share the details a venue needs to host you, such as the name on the booking and party size.</li><li>Apply and track deals and respond to support requests.</li><li>Understand which pages and venues are useful so we can improve the product.</li><li>Send service messages, and marketing messages only where you have opted in.</li><li>Meet legal obligations and prevent misuse or fraud.</li></ul>'''),
        ("cookies", "Cookies and local storage", '''<p>This website stores your selected city in your browser's local storage so the restaurant filters keep it on your next visit. We do not use advertising cookies on this site.</p><p>If we add analytics, it will be configured to avoid identifying individual visitors. You can clear local storage at any time through your browser settings.</p>'''),
        ("sharing", "When we share information", '''<p>We share information with:</p><ul><li><strong>Venues and hosts</strong>, limited to what is needed to honour a booking or experience.</li><li><strong>Service providers</strong> that host our infrastructure, send email or provide analytics, under contractual confidentiality obligations.</li><li><strong>Authorities</strong> where required by law or to protect the rights and safety of users, venues or DineCircle.</li></ul><p>We do not sell personal information.</p>'''),
        ("retention", "How long we keep information", '''<p>Account and booking records are kept while your account is active and for a reasonable period afterwards to meet legal, accounting and dispute-resolution needs. Support messages are kept for up to 24 months. Aggregated analytics that cannot identify you may be kept longer.</p>'''),
        ("your-rights", "Your choices and rights", f'''<p>You can ask to access, correct or delete your personal information, or withdraw marketing consent, by emailing <a href="mailto:{EMAIL}">{EMAIL}</a>. We will respond within a reasonable period. Deleting your account removes your profile; limited booking records may be retained where the law requires it.</p><p>Website enquiry records are deleted once the enquiry is closed and a venue or guest relationship exists, or on request if it does not.</p>'''),
        ("security", "Security", '''<p>We use access controls, encryption in transit and least-privilege access for staff and partners. No system is perfectly secure; if we become aware of a breach affecting your information, we will notify affected users and the relevant authorities as required.</p>'''),
        ("children", "Children", '''<p>DineCircle is not directed at children under 16, and we do not knowingly collect their personal information. If you believe a child has provided information, contact us and we will remove it.</p>'''),
        ("changes", "Changes to this policy", '''<p>We may update this policy as the product changes. The effective date at the top of this page will change, and material updates will be announced in the app or by email where appropriate.</p>'''),
    ]
    return legal_page(
        "Privacy Policy",
        "How DineCircle collects, uses, shares and protects personal information across its website, customer app and partner app.",
        "DineCircle collects the minimum information needed to help you discover restaurants, book tables and join dining experiences. This policy explains what we hold and why.",
        sections,
        related='<p class="prose-note">Related: the <a href="terms.html">terms of service</a> and the <a href="community-guidelines.html">community guidelines</a>. To exercise a right, use the <a href="contact.html">contact page</a> and choose Privacy or my account.</p>',
    )


def build_terms():
    sections = [
        ("about", "About these terms", f'''<p>These terms govern your use of the DineCircle website, customer app and partner app (together, the "service"), operated from Karachi, Pakistan. By using the service, you agree to these terms. If you do not agree, please do not use the service.</p>'''),
        ("what-we-are", "What DineCircle is, and is not", '''<p>DineCircle is a discovery platform. We publish venue information, menus, deals and hosted experiences, and we help guests reserve tables or join experiences.</p><p>We are not the restaurant, café or host. We do not prepare or deliver food, set venue prices, or provide hospitality. The contract for food, drinks and service is between you and the venue. Any complaint about a meal or service should be raised with the venue first; we will help where we reasonably can.</p>'''),
        ("using-the-site", "Using the site", '''<p>You agree to use the service lawfully and not to:</p><ul><li>Copy, scrape or resell venue data, menus or the service itself without permission.</li><li>Post false reviews, impersonate another person or attempt to manipulate bookings or deals.</li><li>Interfere with the security or availability of the service.</li><li>Use the service for commercial purposes unrelated to a genuine booking or partnership.</li></ul>'''),
        ("accounts", "Accounts and bookings", '''<p>An account is required to book tables and join experiences in the app. Keep your login details secure and tell us promptly if you suspect misuse. Booking a table is free. Venue cancellation, seating and no-show policies apply; where a venue requires a cancellation notice, it will be shown before you confirm.</p>'''),
        ("menus", "Menus, prices and venue information", '''<p>Venues supply their menus, prices, opening hours and amenities. Prices are in Pakistani rupees and can change with the season or availability. While we ask venues to keep details current, DineCircle does not guarantee that every item, price or hour is accurate at the moment you visit.</p><p>This website currently shows preview content for the Karachi pilot. Confirm menu items and prices with the venue before ordering.</p>'''),
        ("deals", "Deals and offers", '''<p>Deals are created by venues and are subject to the terms shown alongside each offer. Unless stated otherwise, a deal is dine-in only, cannot be combined with another offer, has no cash alternative and may be withdrawn at any time. The venue decides whether an offer applies to your bill. DineCircle does not charge you for redeeming a deal and never asks for card details on this website.</p>'''),
        ("experiences", "Dining experiences", '''<p>Experiences are hosted by creators or community hosts at a partner venue. Joining is free and reserves a seat; the estimated dining cost shown is paid directly to the venue on the day. Seat counts are limited. Hosts and venues may need to change a date, menu or format; if that happens, we will contact you as early as possible.</p><p>Guests are expected to treat hosts, venue staff and other guests with respect. We may refuse or cancel a participation that is abusive, unsafe or disruptive.</p>'''),
        ("partners", "Partner subscriptions", f'''<p>Venue listings are available on a partner subscription of PKR {PRICE_MONTHLY} per month or PKR {PRICE_YEARLY} per year. DineCircle charges no booking commission. Subscriptions are activated manually after payment by bank transfer, JazzCash or Easypaisa and verification by our team. Subscription fees are separate from any food, beverage or hosting cost.</p><p>A listing is not an endorsement of a venue, and a verified badge confirms that we have reviewed partnership details, not that we guarantee every dish or service.</p><p>A partner application submitted on this website is an enquiry, not an agreement. A partnership begins only when a subscription is activated, and the listing terms on <a href="for-restaurants.html">the partner page</a> describe what is included.</p>'''),
        ("content", "Content and intellectual property", '''<p>The DineCircle name, logo, site design and original copy belong to DineCircle. Venue names, menus, photographs and trade marks belong to their respective owners and are used to describe the venues. You may share links to the service and short excerpts with attribution, but you may not copy the site or its database at scale without written permission.</p>'''),
        ("liability", "Disclaimers and liability", '''<p>The service is provided on an "as is" and "as available" basis. We take reasonable care in publishing information, but we do not warrant that the service will be uninterrupted or error-free, or that venue information is complete and current.</p><p>To the extent permitted by law, DineCircle is not liable for indirect losses, or for the acts or omissions of venues and hosts, including food quality, service, pricing, allergies or availability. Nothing in these terms limits liability that cannot lawfully be limited, including for fraud or death or personal injury caused by negligence.</p>'''),
        ("changes", "Changes to these terms", '''<p>We may update these terms as the service evolves. The effective date will change and material updates will be communicated in the app or by email. Continuing to use the service after an update means you accept the revised terms.</p>'''),
        ("law", "Governing law", '''<p>These terms are governed by the laws of Pakistan. Disputes will be subject to the jurisdiction of the courts of Karachi, unless a mandatory consumer protection law in your location provides otherwise.</p>'''),
    ]
    return legal_page(
        "Terms & Conditions",
        "The terms that apply when you use DineCircle: discovery, bookings, deals, dining experiences, partner subscriptions and liability.",
        "These terms explain what DineCircle does, what it does not do, and the rules that apply when you browse venues, book a table, redeem a deal or join an experience.",
        sections,
        related='<p class="prose-note">Related: the <a href="privacy.html">privacy policy</a> and the <a href="community-guidelines.html">community guidelines</a>, which cover conduct at a hosted table and how reports are handled.</p>',
    )


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

def write(path, content):
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(enhance_page(path, content), encoding="utf-8")
    return target


def write_qr():
    """Generate the download QR at build time so it can never drift from the
    canonical origin in seo-config.json. Only rewritten when the target moves."""
    import qrcode
    from qrcode.image.svg import SvgPathImage

    target = qr_target()
    out = ROOT / "assets" / "images" / "qr-download.svg"
    marker = out.with_suffix(".svg.target")
    current = marker.read_text(encoding="utf-8").strip() if marker.exists() else ""
    if current == target and out.exists():
        return
    out.parent.mkdir(parents=True, exist_ok=True)
    img_obj = qrcode.make(target, image_factory=SvgPathImage, box_size=10, border=2)
    svg = img_obj.to_string().decode("utf-8")
    if svg.startswith("<?xml"):
        svg = svg[svg.index("?>") + 2:].lstrip()
    out.write_text(svg, encoding="utf-8")
    marker.write_text(target, encoding="utf-8")


def main():
    written = 0
    paths = []
    write_qr()
    pages = {
        "index.html": build_home(),
        "how-it-works.html": build_how_it_works(),
        "for-restaurants.html": build_for_restaurants(),
        "become-a-partner.html": build_become_a_partner(),
        "for-hosts.html": build_for_hosts(),
        "download.html": build_download(),
        "contact.html": build_contact(),
        "community-guidelines.html": build_community_guidelines(),
        "restaurants.html": build_restaurants(),
        "deals.html": build_deals(),
        "experiences.html": build_experiences(),
        "hosts.html": build_hosts(),
        "about.html": build_about(),
        "privacy.html": build_privacy(),
        "terms.html": build_terms(),
    }
    for path, content in pages.items():
        write(path, content)
        paths.append(path)
        written += 1
    for v in VENUES:
        write(f'restaurants/{v["slug"]}.html', build_venue(v))
        paths.append(f'restaurants/{v["slug"]}.html')
        written += 1
    for e in EXPERIENCES:
        write(f'experiences/{e["slug"]}.html', build_experience(e))
        paths.append(f'experiences/{e["slug"]}.html')
        written += 1
    for h in HOSTS:
        write(f'hosts/{h["slug"]}.html', build_host(h))
        paths.append(f'hosts/{h["slug"]}.html')
        written += 1
    write_crawl_files(paths)
    print(f"Built {written} pages into {ROOT}")


if __name__ == "__main__":
    main()
