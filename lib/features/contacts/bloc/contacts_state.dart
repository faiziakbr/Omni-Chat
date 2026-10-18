part of 'contacts_bloc.dart';

enum ContactsStatus { initial, loading, success, failure }

final class ContactsState extends Equatable {
  const ContactsState({
    this.status = ContactsStatus.initial,
    this.contacts = const [],
    this.presence = const {},
    this.summaries = const {},
  });

  final ContactsStatus status;
  final List<Contact> contacts;
  final Map<String, Presence> presence;

  /// Last local message + unread count per peer uid.
  final Map<String, ConversationSummary> summaries;

  /// Contacts ordered by latest activity (local message or contact update).
  List<Contact> get sortedContacts {
    DateTime lastActivity(Contact c) {
      final last = summaries[c.uid]?.last.time;
      return last != null && last.isAfter(c.updatedAt) ? last : c.updatedAt;
    }

    return [...contacts]..sort((a, b) => lastActivity(b).compareTo(lastActivity(a)));
  }

  bool isOnline(String uid) => presence[uid]?.online ?? false;

  ContactsState copyWith({
    ContactsStatus? status,
    List<Contact>? contacts,
    Map<String, Presence>? presence,
    Map<String, ConversationSummary>? summaries,
  }) => ContactsState(
    status: status ?? this.status,
    contacts: contacts ?? this.contacts,
    presence: presence ?? this.presence,
    summaries: summaries ?? this.summaries,
  );

  @override
  List<Object?> get props => [status, contacts, presence, summaries];
}
