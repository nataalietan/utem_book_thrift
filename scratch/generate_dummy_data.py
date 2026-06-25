import csv
import random
import uuid
from datetime import datetime

users = []
for i in range(10):
    user_id = str(uuid.uuid4())
    users.append({
        'userID': user_id,
        'fullName': f'Student {i+1}',
        'email': f'B032{random.randint(10000, 99999)}@student.utem.edu.my',
        'role': 'Student',
        'created_at': datetime.now().isoformat(),
        'gender': random.choice(['Male', 'Female']),
        'faculty': random.choice(['FTMK', 'FTKE', 'FTKM', 'FTKEK', 'FAIX', 'FPTT', 'FTKIP', 'SPAB', 'IPTK']),
        'study_level': random.choice(['Diploma', 'Degree', 'Master\'s', 'PhD'])
    })

with open('dummy_users.csv', 'w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=users[0].keys())
    writer.writeheader()
    writer.writerows(users)

textbooks = []
domains = [
    'Computer Science & IT', 'Engineering & Engineering Technology',
    'Business & Technology Management', 'Mathematics & Sciences',
    'Humanities & Social Sciences', 'Languages & Linguistics',
    'Research Methodology'
]
titles = [
    'Calculus Early Transcendentals', 'Introduction to Algorithms',
    'Clean Code', 'Database System Concepts', 'Operating System Concepts',
    'Engineering Mechanics', 'Fundamentals of Physics', 'Business Ethics'
]

for i in range(50):
    original_price = random.randint(50, 200)
    listing_price = round(original_price * random.uniform(0.3, 0.7), 2)
    
    textbooks.append({
        'textbookID': str(uuid.uuid4()),
        'sellerID': random.choice(users)['userID'],
        'title': random.choice(titles),
        'faculty': random.choice(['FTMK', 'FTKE', 'FTKM', 'FTKEK', 'FAIX', 'FPTT', 'FTKIP', 'SPAB', 'IPTK']),
        'edition': random.randint(1, 10),
        'conditionScore': random.randint(1, 4),
        'originalPrice': original_price,
        'isLatestEdition': random.choice(['true', 'false']),
        'status': random.choice(['Pending Approval', 'Available', 'Available', 'Available']),
        'created_at': datetime.now().isoformat(),
        'image_url': 'https://via.placeholder.com/150',
        'description': 'Used but in good condition.',
        'domain': random.choice(domains),
        'studyLevel': random.choice(['Diploma', 'Degree']),
        'listingPrice': listing_price,
        'isDeleteRequested': 'false',
        'isArchived': 'false'
    })

with open('dummy_textbooks.csv', 'w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=textbooks[0].keys())
    writer.writeheader()
    writer.writerows(textbooks)

print("Generated dummy_users.csv and dummy_textbooks.csv")
