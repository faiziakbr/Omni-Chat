part of 'contacts_bloc.dart';

sealed class ContactsEvent extends Equatable {
  const ContactsEvent();
  @override
  List<Object?> get props => [];
}

final class ContactsSubscriptionRequested extends ContactsEvent {
  const ContactsSubscriptionRequested();
}

final class _ContactPresenceChanged extends ContactsEvent {
  const _ContactPresenceChanged(this.uid, this.presence);
  final String uid;
  final Presence presence;
  @override
  List<Object?> get props => [uid, presence];
}
