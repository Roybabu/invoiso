class Supplier {
  String id;
  String name;
  String email;
  String phone;
  String address;
  String gstin;
  String businessName;
  String contactPerson;
  String notes;
  String createdAt;

  Supplier({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.gstin,
    this.businessName = '',
    this.contactPerson = '',
    this.notes = '',
    required this.createdAt,
  });

  // Convert a Map into a Supplier object
  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      gstin: map['gstin'] ?? '',
      businessName: map['business_name'] ?? '',
      contactPerson: map['contact_person'] ?? '',
      notes: map['notes'] ?? '',
      createdAt: map['created_at'] ?? '',
    );
  }

  // Convert a Supplier object into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'gstin': gstin,
      'business_name': businessName,
      'contact_person': contactPerson,
      'notes': notes,
      'created_at': createdAt,
    };
  }
}
