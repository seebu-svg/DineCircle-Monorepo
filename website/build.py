#!/usr/bin/env python3
"""DineCircle website generator.

Builds the static multi-page site (listing pages, per-venue / per-experience /
per-host detail pages, legal pages) from one content model so the header,
footer and card components never drift. Run: python3 build.py
"""
from pathlib import Path
from urllib.parse import quote
import html
import unicodedata
from seo import enhance_page, write_crawl_files

ROOT = Path(__file__).parent
SITE_NAME = "DineCircle"
EMAIL = "hello@dinecircle.app"
PARTNER_EMAIL = "partners@dinecircle.app"
EFFECTIVE = "7 November 2026"


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
    ("Restaurants", "restaurants.html", "restaurants"),
    ("Deals", "deals.html", "deals"),
    ("Experiences", "experiences.html", "experiences"),
    ("Hosts", "hosts.html", "hosts"),
    ("About", "about.html", "about"),
]


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
            <span class="nav-extra__city">{icon("pin")} Karachi</span>
            <button class="btn btn--primary" type="button" data-app-cta>Get the app</button>
          </div>
        </nav>
        <div class="header-actions">
          <div class="city-picker" data-city-picker>
            <button class="city-btn" type="button" aria-expanded="false" aria-haspopup="listbox" aria-controls="cityMenu">
              {icon("pin")}<span data-city-label>Karachi</span>{icon("chevron", "icon icon--sm chevron")}
            </button>
            <ul class="city-menu" id="cityMenu" role="listbox" aria-label="Choose a city" hidden>
              <li role="option" aria-selected="true" tabindex="-1" data-city="Karachi"><span>Karachi</span><span class="pill pill--live">Live</span></li>
              <li role="option" aria-selected="false" aria-disabled="true" tabindex="-1" data-city="Lahore"><span>Lahore</span><span class="pill">Soon</span></li>
              <li role="option" aria-selected="false" aria-disabled="true" tabindex="-1" data-city="Islamabad"><span>Islamabad</span><span class="pill">Soon</span></li>
            </ul>
          </div>
          <button class="btn btn--primary btn--sm header-cta" type="button" data-app-cta>Get the app</button>
          <button class="nav-toggle" type="button" aria-expanded="false" aria-controls="primaryNav" aria-label="Open menu" data-nav-toggle>
            <span></span><span></span><span></span>
          </button>
        </div>
      </div>
    </header>'''


FOOTER_COLUMNS = [
    ("Explore", [
        ("Restaurants", "restaurants.html"),
        ("Deals", "deals.html"),
        ("Experiences", "experiences.html"),
        ("Hosts", "hosts.html"),
    ]),
    ("Company", [
        ("About DineCircle", "about.html"),
        ("Contact us", "about.html#contact"),
        ("How it works", "index.html#how-it-works"),
        ("Partner with us", "about.html#partners"),
    ]),
    ("Legal", [
        ("Privacy Policy", "privacy.html"),
        ("Terms & Conditions", "terms.html"),
    ]),
]


def footer(base):
    cols = ""
    for title, links in FOOTER_COLUMNS:
        items = "".join(f'<li><a href="{base}{href}">{label}</a></li>' for label, href in links)
        cols += f'<div class="footer-col"><h3>{title}</h3><ul>{items}</ul></div>'
    return f'''<footer class="site-footer">
      <div class="container footer-grid">
        <div class="footer-brand">
          <a class="brand brand--light" href="{base}index.html" aria-label="DineCircle home">
            {brand_mark(base, light=True)}
            <span class="brand-word">Dine<span>Circle</span></span>
          </a>
          <p class="footer-tagline">Your next great meal starts here.</p>
          <p>DineCircle is your local guide to discovering where to eat and what’s worth going out for. Explore food, places, and people in Karachi.</p>
          <div class="socials" aria-label="Social channels">
            <a href="https://www.instagram.com/" target="_blank" rel="noopener noreferrer" aria-label="DineCircle on Instagram">{icon("instagram")}</a>
            <a href="https://www.facebook.com/" target="_blank" rel="noopener noreferrer" aria-label="DineCircle on Facebook">{icon("facebook")}</a>
            <a href="https://www.tiktok.com/" target="_blank" rel="noopener noreferrer" aria-label="DineCircle on TikTok">{icon("tiktok")}</a>
            <a href="https://www.linkedin.com/" target="_blank" rel="noopener noreferrer" aria-label="DineCircle on LinkedIn">{icon("linkedin")}</a>
          </div>
        </div>
        {cols}
        <div class="footer-col footer-contact">
          <h3>Contact</h3>
          <ul>
            <li><a href="mailto:{EMAIL}">{EMAIL}</a></li>
            <li><a href="mailto:{PARTNER_EMAIL}">{PARTNER_EMAIL}</a></li>
            <li>Karachi, Pakistan</li>
            <li>Support: Mon–Sat, 10 AM–7 PM</li>
          </ul>
          <button class="btn btn--light btn--sm" type="button" data-app-cta>Get the app</button>
        </div>
      </div>
      <div class="container footer-bottom">
        <p>© 2026 DineCircle. Free for diners, always.</p>
        <p class="footer-fine">Karachi pilot · Prices in PKR · Preview content for venue menus and offers.</p>
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
          <a class="btn btn--primary" href="mailto:{EMAIL}?subject=DineCircle%20launch%20access">Get launch access</a>
          <a class="btn btn--outline" href="{base}about.html#contact">Contact us</a>
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
    featured = [v for v in VENUES if v.get("featured")][:4]
    if len(featured) < 4:
        featured += [v for v in VENUES if v not in featured][:4 - len(featured)]
    featured_cards = "".join(venue_card(v, "") for v in featured)
    home_deals = [ALL_DEALS[0], VENUES[3]["deals"][0], VENUES[10]["deals"][0]]
    deal_cards = "".join(deal_card(d, "", show_contact=False) for d in home_deals)
    exp_cards = "".join(exp_card(e, "") for e in EXPERIENCES[:3])
    host_cards = "".join(host_card(h, "") for h in HOSTS)

    area_specs = [
        ("Do Darya", "Sea-facing dinners and late-night grills"),
        ("Clifton", "Neighbourhood cafés and courtyard dining"),
        ("Zamzama", "Coffee, chocolate and wood-fired pizza"),
        ("DHA Phase 8", "Mediterranean plates and family grills"),
        ("DHA Phase 6", "Espresso bars and quick lunches"),
        ("DHA Phase 5", "Pizza and pasta around the corner"),
    ]
    area_cards = ""
    for area, blurb in area_specs:
        places = [v for v in VENUES if area.lower() in v["area"].lower()]
        sample = ", ".join(v["name"] for v in places[:2])
        count_label = "place" if len(places) == 1 else "places"
        area_cards += f'''<a class="area-card" href="restaurants.html?q={quote(area)}">
          <span class="area-card__count">{len(places)} {count_label}</span>
          <h3>{esc(area)}</h3>
          <p>{esc(blurb)}</p>
          <span class="area-card__sample">{esc(sample)}</span>
          <span class="area-card__link">Browse {esc(area)} <span aria-hidden="true">→</span></span>
        </a>'''

    home_faqs = [
        ("Is DineCircle free?",
         "Yes. Browsing, booking tables and joining dining experiences are free for diners. DineCircle takes no booking commission. You pay the restaurant for your food and drinks."),
        ("How do deals work?",
         "Find an offer on the Deals page or the venue page, show it to your server before ordering, and the venue applies it to the bill. Some offers need a code; others just need you to ask. Each deal lists its own terms."),
        ("What does joining an experience cost?",
         "Joining is free. Each experience shows an estimated dining cost per person, which you pay directly to the venue on the day. There is no online checkout and no DineCircle fee."),
        ("Are the menus and prices accurate?",
         "Menus, prices and opening hours are supplied by each venue and can change with the season. This site shows preview content for the Karachi pilot. Confirm details with the restaurant before you order."),
        ("Which cities do you cover?",
         "Karachi is live. Lahore and Islamabad are next, with the same model: free for diners, subscription-based for partners and zero booking commission."),
    ]
    faq_items = "".join(
        f'<details class="faq-item"><summary>{esc(q)}<span class="faq-icon" aria-hidden="true"></span></summary><p>{esc(a)}</p></details>'
        for q, a in home_faqs
    )

    dish_total = sum(len(block["items"]) for v in VENUES for block in v["menu"])

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
        <article class="editorial-slide is-active" data-hero-slide role="group" aria-roledescription="slide" aria-label="1 of 3: Restaurants & cafés">
          <img class="editorial-slide__image" src="assets/images/venue_rooftop.webp" alt="A restaurant terrace glowing under evening lights" fetchpriority="high" decoding="async">
          <div class="container editorial-slide__inner">
            <div class="editorial-slide__copy">
              <p class="editorial-kicker"><span></span> Your local food guide</p>
              <h1>Your next great meal<br><em>starts here.</em></h1>
              <p class="editorial-slide__description">Discover restaurants and cafés, explore menus and deals, and find dining experiences near you.</p>
              <div class="editorial-slide__actions"><a class="btn btn--primary" href="restaurants.html">Explore restaurants <span aria-hidden="true">↗</span></a><a class="editorial-link" href="about.html">Meet DineCircle <span aria-hidden="true">→</span></a></div>
              <p class="editorial-slide__assurance">Karachi, Pakistan <span aria-hidden="true">·</span> Free for diners</p>
            </div>
            <div class="editorial-slide__caption"><span>01 / THE DINECIRCLE EDIT</span><strong>A taste of your neighbourhood</strong></div>
          </div>
        </article>
        <article class="editorial-slide" data-hero-slide role="group" aria-roledescription="slide" aria-label="2 of 3: Dining offers" hidden inert>
          <img class="editorial-slide__image" src="assets/images/dish_steak.webp" alt="A beautifully plated dinner ready to be enjoyed" loading="lazy" decoding="async">
          <div class="container editorial-slide__inner">
            <div class="editorial-slide__copy">
              <p class="editorial-kicker"><span></span> Good food. Clear value.</p>
              <h2>Find your favourite.<br><em>Savour the value.</em></h2>
              <p class="editorial-slide__description">Explore dining deals with clear prices and terms. See what’s included, check when an offer applies, and choose what works for your table.</p>
              <div class="editorial-slide__actions"><a class="btn btn--primary" href="deals.html">Discover dining offers <span aria-hidden="true">↗</span></a><a class="editorial-link" href="about.html">Meet DineCircle <span aria-hidden="true">→</span></a></div>
              <p class="editorial-slide__assurance">Karachi, Pakistan <span aria-hidden="true">·</span> Free for diners</p>
            </div>
            <div class="editorial-slide__caption"><span>02 / THE DINECIRCLE EDIT</span><strong>A little extra to savour</strong></div>
          </div>
        </article>
        <article class="editorial-slide" data-hero-slide role="group" aria-roledescription="slide" aria-label="3 of 3: Hosted experiences" hidden inert>
          <img class="editorial-slide__image" src="assets/images/hero_tasting.webp" alt="An intimate candlelit table set for a shared dinner" loading="lazy" decoding="async">
          <div class="container editorial-slide__inner">
            <div class="editorial-slide__copy">
              <p class="editorial-kicker"><span></span> Food brings us together</p>
              <h2>A reason to go out.<br><em>A table to share.</em></h2>
              <p class="editorial-slide__description">From a relaxed brunch to a shared dinner, discover experiences led by local hosts and food creators. Find good food, fresh conversation, and a reason to get together.</p>
              <div class="editorial-slide__actions"><a class="btn btn--primary" href="experiences.html">Explore experiences <span aria-hidden="true">↗</span></a><a class="editorial-link" href="about.html">Meet DineCircle <span aria-hidden="true">→</span></a></div>
              <p class="editorial-slide__assurance">Karachi, Pakistan <span aria-hidden="true">·</span> Free for diners</p>
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
        <div><span class="editorial-small">A city full of flavour</span><h2>What are you craving?</h2></div>
        <form class="discovery-search" action="restaurants.html" method="get" role="search" data-search-form>
          <label class="sr-only" for="heroQuery">Search restaurants, dishes or cuisines</label>
          <span aria-hidden="true">⌕</span><input id="heroQuery" name="q" type="search" placeholder="Try BBQ, brunch or your favourite café" autocomplete="off">
          <button class="btn btn--primary" type="submit">Find a table <span aria-hidden="true">→</span></button>
        </form>
      </div>
      <div class="container discovery-bar__tags"><span>Follow your craving</span><a href="restaurants.html?q=BBQ">Smoky BBQ ↗</a><a href="restaurants.html?q=Brunch">Slow brunches ↗</a><a href="restaurants.html?q=Coffee">Coffee & conversation ↗</a><a href="restaurants.html?cuisine=seafood">By the sea ↗</a></div>
    </section>

    <section class="trust-strip" aria-label="DineCircle at a glance">
      <div class="container trust-grid">
        <div><strong>8</strong><span>verified partners</span></div>
        <div><strong>22</strong><span>live offers</span></div>
        <div><strong>5</strong><span>hosted experiences</span></div>
        <div><strong>0%</strong><span>booking commission</span></div>
      </div>
    </section>

    <section class="section" id="featured">
      <div class="container">
        {section_head("Places", "Find a place that feels like your kind of place",
                      "Sea-facing dinners, neighbourhood cafés, and familiar flavours. Explore Karachi’s restaurants by cuisine, atmosphere, area, and menu.",
                      '<a class="btn btn--outline" href="restaurants.html">Explore Restaurants</a>')}
        <div class="venue-grid">{featured_cards}</div>
        <div class="cuisine-rail">
          <span class="cuisine-rail__label">Browse by craving</span>
          <div class="chips">{cuisine_chips}</div>
        </div>
      </div>
    </section>

    <section class="section section--cream" id="neighbourhoods">
      <div class="container">
        {section_head("Neighbourhoods", "Find your corner of Karachi",
                      "From sea-facing tables on Do Darya to espresso bars on Zamzama. Pick an area and see every place we cover there.",
                      '<a class="btn btn--outline" href="restaurants.html">Explore Restaurants</a>')}
        <div class="area-grid">{area_cards}</div>
      </div>
    </section>

    <section class="section" id="deals">
      <div class="container">
        {section_head("Value", "Good food, with the details up front",
                      "Browse dining deals with clear prices and terms. Check the offer, any minimum spend, and when it applies before you decide.",
                      '<a class="btn btn--outline" href="deals.html">Discover Deals</a>')}
        <div class="deal-grid deal-grid--three">{deal_cards}</div>
      </div>
    </section>

    <section class="section section--cream" id="experiences">
      <div class="container">
        {section_head("Experiences", "Find what’s worth going out for",
                      "A weekend brunch, a coffee meetup, or a dinner worth sharing. Explore local dining experiences, meet your host, and see what to expect before you join.",
                      '<a class="btn btn--outline" href="experiences.html">Explore Experiences</a>')}
        <div class="exp-grid">{exp_cards}</div>
      </div>
    </section>

    <section class="section" id="hosts">
      <div class="container">
        {section_head("People", "Let local people lead you to good food",
                      "Meet the local hosts and food creators guiding discovery through Karachi’s food culture, one favourite place and shared table at a time.",
                      '<a class="btn btn--outline" href="hosts.html">Discover Hosts</a>')}
        <div class="host-grid">{host_cards}</div>
      </div>
    </section>

    <section class="section section--cream" id="why">
      <div class="container">
        {section_head("Why DineCircle", "Clear prices, no commission, no checkout",
                      f"{dish_total} dishes with PKR prices across {len(VENUES)} venues, {len(ALL_DEALS)} live offers and {len(EXPERIENCES)} hosted experiences. Every listing is supplied by the venue.")}
        <div class="value-grid">
          <article class="value-card">
            <span class="style-icon">{icon("check")}</span>
            <h3>Free for diners</h3>
            <p>Browsing, booking a table and joining a hosted experience cost nothing. DineCircle takes no booking commission, so you pay the restaurant for your food and drinks.</p>
          </article>
          <article class="value-card">
            <span class="style-icon">{icon("book")}</span>
            <h3>Prices before you go</h3>
            <p>Every venue page lists menu sections, dishes, PKR prices, opening hours and area, so you can plan a meal without guessing the bill.</p>
          </article>
          <article class="value-card">
            <span class="style-icon">{icon("verified")}</span>
            <h3>No checkout, no wallet</h3>
            <p>There is no in-app payment and no card details stored on DineCircle. Show your booking or deal at the venue and settle the bill directly.</p>
          </article>
        </div>
      </div>
    </section>

    <section class="section" id="how-it-works">
      <div class="container">
        {section_head("How it works", "Discover. Choose. Visit.",
                      "Find a place, explore the menu, and make a plan. Your next meal starts with a little local discovery.")}
        <ol class="steps">
          <li class="step">
            <span class="step-num">01</span>
            <span class="step-icon">{icon("search")}</span>
            <h3>Discover</h3>
            <p>Search restaurants, cafés and dishes across Karachi. Filter by cuisine, area or price and read the full menu before you go.</p>
          </li>
          <li class="step">
            <span class="step-num">02</span>
            <span class="step-icon">{icon("calendar")}</span>
            <h3>Choose</h3>
            <p>Pick a deal, book a table or join a hosted experience. Reservations and experience seats cost nothing to book.</p>
          </li>
          <li class="step">
            <span class="step-num">03</span>
            <span class="step-icon">{icon("check")}</span>
            <h3>Visit</h3>
            <p>Show your booking or deal at the venue and pay the restaurant directly for your meal. No in-app payment, no hidden fee.</p>
          </li>
        </ol>
      </div>
    </section>

    <section class="section section--cream" id="faq">
      <div class="container faq-layout">
        <div>
          <p class="eyebrow">FAQs</p>
          <h2>Questions, answered</h2>
          <p class="section-note">Still stuck? Email <a href="mailto:hello@dinecircle.app">hello@dinecircle.app</a> and we will reply within one working day.</p>
          <div class="about-actions"><a class="btn btn--outline" href="about.html#faq">Read all FAQs</a></div>
        </div>
        <div class="faq-list">{faq_items}</div>
      </div>
    </section>

    <section class="app-band" id="app" aria-label="Get the DineCircle app">
      <div class="container app-band__inner">
        <div class="app-band__copy">
          <p class="eyebrow">The DineCircle app</p>
          <h2>Carry your next table in your pocket</h2>
          <p>Menus, deals and bookings in one place. Browse before you leave, show your booking at the door, and pay the restaurant directly when you are done.</p>
          <ul class="check-list check-list--light">
            <li>{icon("book")} Full menus with PKR prices</li>
            <li>{icon("spark")} Deals with clear terms and codes</li>
            <li>{icon("calendar")} Table bookings and hosted experiences</li>
          </ul>
          <div class="app-band__actions">
            <button class="btn btn--primary" type="button" data-app-cta>Get the app</button>
            <a class="btn btn--ghost-light" href="#how-it-works">How booking works</a>
          </div>
          <p class="app-band__fine">Free for diners. Download links are opening in phases across Karachi.</p>
        </div>
        <figure class="app-band__figure">
          <img src="assets/images/venue_bar.webp" alt="Guests settling in at a warmly lit restaurant bar" loading="lazy" decoding="async">
        </figure>
      </div>
    </section>

    <section class="section" id="partners">
      <div class="container partner-panel">
        <div class="partner-copy">
          <p class="eyebrow">For restaurants &amp; cafés</p>
          <h2>Put your full menu on the map</h2>
          <p>List your venue, publish a QR-ready menu, run deals and host experiences. DineCircle charges a flat subscription and never a commission on your bookings.</p>
          <ul class="check-list">
            <li>{icon("check")} PKR 5,000 per month or PKR 50,000 per year</li>
            <li>{icon("check")} 0% booking commission</li>
            <li>{icon("check")} No payment gateway or payout setup</li>
            <li>{icon("check")} Activation after a simple bank transfer, JazzCash or Easypaisa payment</li>
          </ul>
          <div class="about-actions">
            <a class="btn btn--primary" href="mailto:partners@dinecircle.app?subject=DineCircle%20partner%20enquiry">Talk to the partner team</a>
            <a class="btn btn--outline" href="restaurants.html">See how listings look</a>
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
          <a class="btn btn--primary btn--block" href="mailto:partners@dinecircle.app?subject=DineCircle%20partner%20enquiry">Request activation</a>
          <p class="aside-fine">Manual activation after payment verification. No commission on any booking.</p>
        </aside>
      </div>
    </section>

    <section class="newsletter-band" id="newsletter" aria-label="DineCircle newsletter">
      <div class="container newsletter-inner">
        <div>
          <p class="eyebrow">Stay in the loop</p>
          <h2>New places, before they get busy</h2>
          <p>Occasional notes on new venues, offers worth leaving home for, and experiences with seats left.</p>
        </div>
        <div>
          <form class="newsletter-form" data-newsletter>
            <label class="sr-only" for="newsletterEmail">Email address</label>
            <input id="newsletterEmail" name="email" type="email" required placeholder="you@example.com" autocomplete="email">
            <button class="btn btn--primary" type="submit">Subscribe</button>
          </form>
          <p class="newsletter-fine">We only email about DineCircle. Prefer to write first? <a href="mailto:hello@dinecircle.app?subject=DineCircle%20newsletter">hello@dinecircle.app</a></p>
        </div>
      </div>
    </section>

    <section class="cta-band">
      <div class="container cta-band__inner">
        <div>
          <p class="eyebrow">Your table is waiting</p>
          <h2>Make your next meal a local discovery.</h2>
          <p>Keep restaurants, menus, deals, and dining experiences close at hand. Discover your next favourite with DineCircle.</p>
        </div>
        <div class="cta-band__actions">
          <button class="btn btn--light" type="button" data-app-cta>Get the app</button>
          <a class="btn btn--ghost-light" href="#partners">Partner with us</a>
        </div>
      </div>
    </section>'''

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
          <a class="btn btn--outline" href="about.html#contact">Contact DineCircle</a>
        </div>
      </div>
    </section>'''
    return page(
        "Restaurants & cafés in Karachi",
        "Browse and filter Karachi restaurants and cafés on DineCircle. Menus, cuisine, price ranges, deals and opening hours.",
        "", "restaurants", body,
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
            <a class="text-link" href="../about.html#contact">Contact us {icon("arrow", "icon icon--sm")}</a>
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
        "../", "restaurants", body, og=f'assets/images/{v["cover"]}.webp',
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
        "Discover 22 restaurant and café deals in Karachi with clear terms, redemption steps and no online payment.",
        "", "deals", body,
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
            <a class="text-link" href="../about.html#contact">Contact DineCircle {icon("arrow", "icon icon--sm")}</a>
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
          <a class="btn btn--outline" href="about.html#contact">Talk to us</a>
        </div>
      </div>
    </section>'''
    return page(
        "Dining hosts and food creators in Karachi",
        "Meet the creators and community hosts behind DineCircle's hosted dinners, brunches and coffee meetups in Karachi.",
        "", "hosts", body,
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
          <a class="btn btn--outline" href="../about.html#contact">Get in touch</a>
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
        "../", "hosts", body, og=f'assets/images/{h["portrait"]}.webp',
    )


# ---------------------------------------------------------------------------
# About & contact
# ---------------------------------------------------------------------------

def build_about():
    faqs = [
        ("Is DineCircle free?",
         "Yes. Browsing, booking tables and joining dining experiences are free for diners. DineCircle takes no booking commission. You pay the restaurant for your food and drinks."),
        ("Do I need the app to book a table?",
         "Table bookings and experience seats are confirmed in the DineCircle app. This website is for discovery: menus, deals, venue details and host profiles. Download links are opening in phases across Karachi."),
        ("How do deals work?",
         "Find an offer on the Deals page or the venue page, show it to your server before ordering, and the venue applies it to the bill. Some offers need a code; others just need you to ask. Each deal lists its own terms."),
        ("What does joining an experience cost?",
         "Joining is free. Each experience shows an estimated dining cost per person, which you pay directly to the venue on the day. There is no online checkout and no DineCircle fee."),
        ("Are the menus and prices accurate?",
         "Menus, prices and opening hours are supplied by each venue and can change with the season. This site shows preview content for the Karachi pilot. Confirm details with the restaurant before you order."),
        ("Which cities do you cover?",
         "Karachi is live. Lahore and Islamabad are next, with the same model: free for diners, subscription-based for partners and zero booking commission."),
    ]
    faq_html = "".join(
        f'''<details class="faq-item">
            <summary>{esc(q)}<span class="faq-icon" aria-hidden="true"></span></summary>
            <p>{esc(a)}</p>
          </details>'''
        for q, a in faqs
    )

    body = f'''{page_hero(
        "About DineCircle",
        "Your local guide to good food and shared tables.",
        "DineCircle is your local guide to discovering where to eat and what’s worth going out for. We bring restaurants, cafés, menus, deals, and dining experiences together, starting with Karachi.",
        crumbs_html=crumbs("", [("Home", "index.html"), ("About & contact", None)]),
    )}
    <section class="section section--flush">
      <div class="container about-split">
        <div>
          <p class="eyebrow">Our story</p>
          <h2>A simpler way to decide where to eat</h2>
          <p class="detail-lede">Good food is part of how we know our city: a favourite café, a family dinner, a new place recommended by someone local. DineCircle helps you explore those possibilities with menus, prices, offers, and the people behind shared dining experiences.</p>
          <p>Explore places for their food and atmosphere, find value with clear prices and terms, and discover experiences with local hosts and food creators. Whether you’re revisiting a favourite or trying somewhere new, we help you make a plan with confidence.</p>
          <div class="about-actions">
            <a class="btn btn--primary" href="restaurants.html">Explore Restaurants</a>
            <a class="btn btn--outline" href="#partners">For restaurants</a>
          </div>
        </div>
        <figure class="about-photo">{img("", "venue_interior", "Dining room at a Karachi restaurant", eager=True)}</figure>
      </div>
    </section>

    <section class="stats-band">
      <div class="container stats-grid">
        <div><strong>11</strong><span>Karachi venues</span></div>
        <div><strong>100+</strong><span>menu items</span></div>
        <div><strong>22</strong><span>launch offers</span></div>
        <div><strong>5</strong><span>hosted experiences</span></div>
      </div>
    </section>

    <section class="section">
      <div class="container">
        {section_head("What we stand for", "Local discovery, with care")}
        <div class="value-grid">
          <article class="value-card"><span class="style-icon">{icon("check")}</span><h3>Free for diners</h3><p>No booking fee, no subscription and no commission on your bill. If a venue charges for food, that is the only charge you see.</p></article>
          <article class="value-card"><span class="style-icon">{icon("book")}</span><h3>Useful details, clearly shared</h3><p>Explore venue menus with prices in PKR and dining offers with their terms, so you know what to expect before you go.</p></article>
          <article class="value-card"><span class="style-icon">{icon("users")}</span><h3>Rooted in local food culture</h3><p>Restaurants, cafés, hosts, and food creators bring Karachi’s food culture to life. Get to know the people and places around your next table.</p></article>
        </div>
      </div>
    </section>

    <section class="section section--cream" id="how-it-works">
      <div class="container">
        {section_head("How it works", "Discover. Choose. Visit.", "No checkout, no wallet, no card details stored on DineCircle.")}
        <ol class="steps">
          <li class="step"><span class="step-num">01</span><span class="step-icon">{icon("search")}</span><h3>Discover</h3><p>Search restaurants, cafés and dishes. Filter by cuisine, price or area and read the full menu before you leave the house.</p></li>
          <li class="step"><span class="step-num">02</span><span class="step-icon">{icon("calendar")}</span><h3>Choose</h3><p>Pick a deal, reserve a table or join a hosted experience. Booking and joining are free.</p></li>
          <li class="step"><span class="step-num">03</span><span class="step-icon">{icon("check")}</span><h3>Visit</h3><p>Show your booking or offer at the venue, eat, and pay the restaurant directly for what you ordered.</p></li>
        </ol>
      </div>
    </section>

    <section class="section" id="partners">
      <div class="container partner-panel">
        <div class="partner-copy">
          <p class="eyebrow">For restaurants &amp; cafés</p>
          <h2>Put your full menu on the map</h2>
          <p>List your venue, publish a QR-ready menu, add deals and host experiences. DineCircle charges a flat subscription, never a commission on your bookings.</p>
          <ul class="check-list">
            <li>{icon("check")} PKR 5,000 per month or PKR 50,000 per year</li>
            <li>{icon("check")} 0% booking commission</li>
            <li>{icon("check")} No payment gateway or payout setup</li>
            <li>{icon("check")} Activation after a simple bank transfer, JazzCash or Easypaisa payment</li>
          </ul>
          <div class="about-actions">
            <a class="btn btn--primary" href="mailto:{PARTNER_EMAIL}?subject=DineCircle%20partner%20enquiry">Talk to the partner team</a>
            <a class="btn btn--outline" href="restaurants.html">See how listings look</a>
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
          <a class="btn btn--primary btn--block" href="mailto:{PARTNER_EMAIL}?subject=DineCircle%20partner%20enquiry">Request activation</a>
          <p class="aside-fine">Manual activation after payment verification. No commission on any booking.</p>
        </aside>
      </div>
    </section>

    <section class="section section--cream" id="faq">
      <div class="container faq-layout">
        <div>
          <p class="eyebrow">FAQs</p>
          <h2>Questions, answered</h2>
          <p class="section-note">Still stuck? Email <a href="mailto:{EMAIL}">{EMAIL}</a> and we will reply within one working day.</p>
        </div>
        <div class="faq-list">{faq_html}</div>
      </div>
    </section>

    <section class="section" id="contact">
      <div class="container contact-layout">
        <div class="contact-copy">
          <p class="eyebrow">Contact</p>
          <h2>Talk to DineCircle</h2>
          <p>Questions about a venue, a deal, an experience or partnering with us? Send a note and the right person will reply.</p>
          <ul class="contact-list">
            <li><span class="contact-icon">{icon("mail")}</span><div><strong>General</strong><a href="mailto:{EMAIL}">{EMAIL}</a></div></li>
            <li><span class="contact-icon">{icon("verified")}</span><div><strong>Partners</strong><a href="mailto:{PARTNER_EMAIL}">{PARTNER_EMAIL}</a></div></li>
            <li><span class="contact-icon">{icon("pin")}</span><div><strong>Office</strong><span>Karachi, Pakistan</span></div></li>
            <li><span class="contact-icon">{icon("clock")}</span><div><strong>Support hours</strong><span>Monday–Saturday, 10 AM–7 PM PKT</span></div></li>
          </ul>
        </div>
        <form class="contact-form" data-contact-form>
          <div class="field-row">
            <label class="field"><span>Name</span><input type="text" name="name" required placeholder="Your name"></label>
            <label class="field"><span>Email</span><input type="email" name="email" required placeholder="you@example.com"></label>
          </div>
          <label class="field"><span>What is this about?</span>
            <select name="topic">
              <option>A restaurant or menu</option>
              <option>A deal</option>
              <option>An experience or host</option>
              <option>Partnering with DineCircle</option>
              <option>Privacy or my account</option>
              <option>Something else</option>
            </select>
          </label>
          <label class="field"><span>Message</span><textarea name="message" rows="6" required placeholder="Tell us what you need."></textarea></label>
          <button class="btn btn--primary" type="submit">Send message</button>
          <p class="form-note">This opens your email app with the message ready to send. We never store form data on this website.</p>
        </form>
      </div>
    </section>'''

    return page(
        "About & contact",
        "About DineCircle: a free, Karachi-first discovery platform for restaurants, cafés, deals and hosted dining experiences. Partner plans, FAQs and contact details.",
        "", "about", body,
    )


# ---------------------------------------------------------------------------
# Legal pages
# ---------------------------------------------------------------------------

def legal_page(title, description, intro, sections):
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
          <p class="prose-note">Questions about this page? Email <a href="mailto:{EMAIL}">{EMAIL}</a>.</p>
        </div>
      </div>
    </section>'''
    return page(title, description, "", "", body)


def build_privacy():
    sections = [
        ("who-we-are", "Who we are", f'''<p>DineCircle is a restaurant discovery platform based in Karachi, Pakistan. This policy explains how we handle personal information on the DineCircle website and in the DineCircle customer and partner apps.</p><p>For privacy questions, contact <a href="mailto:{EMAIL}">{EMAIL}</a>.</p>'''),
        ("information-we-collect", "Information we collect", '''<p>We collect only what we need to run the service:</p><ul><li><strong>Account details</strong> you provide in the app, such as your name, email address and phone number.</li><li><strong>Booking and experience details</strong>, including the venue, date, party size and any dietary notes you choose to share.</li><li><strong>Deal redemptions</strong> recorded when a venue applies an offer.</li><li><strong>Support messages</strong> you send to us.</li><li><strong>Technical information</strong> such as device type, browser, approximate location derived from your IP address, and pages viewed.</li></ul><p>This marketing website does not create accounts and does not process payments.</p>'''),
        ("how-we-use-it", "How we use information", '''<p>We use information to:</p><ul><li>Create and secure your account and confirm bookings or experience seats.</li><li>Share the details a venue needs to host you, such as the name on the booking and party size.</li><li>Apply and track deals and respond to support requests.</li><li>Understand which pages and venues are useful so we can improve the product.</li><li>Send service messages, and marketing messages only where you have opted in.</li><li>Meet legal obligations and prevent misuse or fraud.</li></ul>'''),
        ("cookies", "Cookies and local storage", '''<p>This website stores your selected city in your browser's local storage so the header remembers it on your next visit. We do not use advertising cookies on this site.</p><p>If we add analytics, it will be configured to avoid identifying individual visitors. You can clear local storage at any time through your browser settings.</p>'''),
        ("sharing", "When we share information", '''<p>We share information with:</p><ul><li><strong>Venues and hosts</strong>, limited to what is needed to honour a booking or experience.</li><li><strong>Service providers</strong> that host our infrastructure, send email or provide analytics, under contractual confidentiality obligations.</li><li><strong>Authorities</strong> where required by law or to protect the rights and safety of users, venues or DineCircle.</li></ul><p>We do not sell personal information.</p>'''),
        ("retention", "How long we keep information", '''<p>Account and booking records are kept while your account is active and for a reasonable period afterwards to meet legal, accounting and dispute-resolution needs. Support messages are kept for up to 24 months. Aggregated analytics that cannot identify you may be kept longer.</p>'''),
        ("your-rights", "Your choices and rights", '''<p>You can ask to access, correct or delete your personal information, or withdraw marketing consent, by emailing <a href="mailto:{EMAIL}">{EMAIL}</a>. We will respond within a reasonable period. Deleting your account removes your profile; limited booking records may be retained where the law requires it.</p>'''),
        ("security", "Security", '''<p>We use access controls, encryption in transit and least-privilege access for staff and partners. No system is perfectly secure; if we become aware of a breach affecting your information, we will notify affected users and the relevant authorities as required.</p>'''),
        ("children", "Children", '''<p>DineCircle is not directed at children under 16, and we do not knowingly collect their personal information. If you believe a child has provided information, contact us and we will remove it.</p>'''),
        ("changes", "Changes to this policy", '''<p>We may update this policy as the product changes. The effective date at the top of this page will change, and material updates will be announced in the app or by email where appropriate.</p>'''),
    ]
    return legal_page(
        "Privacy Policy",
        "How DineCircle collects, uses, shares and protects personal information across its website, customer app and partner app.",
        "DineCircle collects the minimum information needed to help you discover restaurants, book tables and join dining experiences. This policy explains what we hold and why.",
        sections,
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
        ("partners", "Partner subscriptions", '''<p>Venue listings are available on a partner subscription of PKR 5,000 per month or PKR 50,000 per year. DineCircle charges no booking commission. Subscriptions are activated manually after payment by bank transfer, JazzCash or Easypaisa and verification by our team. Subscription fees are separate from any food, beverage or hosting cost.</p><p>A listing is not an endorsement of a venue, and a verified badge confirms that we have reviewed partnership details, not that we guarantee every dish or service.</p>'''),
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
    )


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

def write(path, content):
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(enhance_page(path, content), encoding="utf-8")
    return target


def main():
    written = 0
    paths = []
    pages = {
        "index.html": build_home(),
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
