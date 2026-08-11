'use strict';

/// Raggio entro cui due persone si vedono.
const MAX_DISTANCE_KM = 50;

const EARTH_RADIUS_KM = 6371;

/**
 * Vero se la preferenza comprende il genere indicato.
 *
 * Deve restare identica a `InterestPreference.covers` lato Dart: se le due
 * definizioni divergono, l'app mostra un criterio e il server ne applica un
 * altro.
 */
function covers(interestedIn, gender) {
  if (interestedIn === 'everyone') {
    return true;
  }

  if (interestedIn === 'women') {
    return gender === 'woman';
  }

  if (interestedIn === 'men') {
    return gender === 'man';
  }

  return false;
}

/** La compatibilita' e' reciproca: devono cercarsi a vicenda. */
function isCompatible(a, b) {
  return covers(a.interestedIn, b.gender) && covers(b.interestedIn, a.gender);
}

function toRadians(degrees) {
  return (degrees * Math.PI) / 180;
}

/** Distanza in chilometri fra due profili, formula dell'emisenoverso. */
function distanceKm(a, b) {
  const deltaLat = toRadians(b.latitude - a.latitude);
  const deltaLng = toRadians(b.longitude - a.longitude);
  const lat1 = toRadians(a.latitude);
  const lat2 = toRadians(b.latitude);

  const h =
    Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2) +
    Math.sin(deltaLng / 2) *
      Math.sin(deltaLng / 2) *
      Math.cos(lat1) *
      Math.cos(lat2);

  return EARTH_RADIUS_KM * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

function hasLocation(profile) {
  return (
    typeof profile.latitude === 'number' && typeof profile.longitude === 'number'
  );
}

/** Un profilo entra nei feed solo se e' completo e localizzato. */
function isEligible(profile) {
  return profile.onboardingCompleted === true && hasLocation(profile);
}

/**
 * Vero se `viewer` puo' vedere `author`.
 *
 * Racchiude tutte le condizioni in un punto solo, cosi' le due funzioni che
 * scrivono i feed non possono applicare criteri diversi fra loro.
 */
function canSee(viewer, author) {
  if (viewer.id === author.id) {
    return false;
  }

  if (!isEligible(viewer) || !isEligible(author)) {
    return false;
  }

  if (!isCompatible(viewer, author)) {
    return false;
  }

  return distanceKm(viewer, author) <= MAX_DISTANCE_KM;
}

/** Eta' in anni compiuti, calcolata dal timestamp Firestore della nascita. */
function ageFrom(birthDate, now) {
  if (!birthDate || typeof birthDate.toDate !== 'function') {
    return 0;
  }

  const birth = birthDate.toDate();
  let age = now.getFullYear() - birth.getFullYear();
  const hadBirthday =
    now.getMonth() > birth.getMonth() ||
    (now.getMonth() === birth.getMonth() && now.getDate() >= birth.getDate());

  if (!hadBirthday) {
    age -= 1;
  }

  return age;
}

function interestsOf(profile) {
  return Array.isArray(profile.interests) ? profile.interests : [];
}

/**
 * Percentuale di affinita': interessi in comune sul totale dei distinti.
 *
 * Deve restare identica a `ProfileInterests.compatibility` lato Dart: se le
 * due divergono, l'app mostrerebbe un numero e il server ne calcolerebbe un
 * altro.
 */
function compatibility(viewer, author) {
  const first = new Set(interestsOf(viewer));
  const second = new Set(interestsOf(author));

  if (first.size === 0 || second.size === 0) {
    return 0;
  }

  let shared = 0;

  for (const id of first) {
    if (second.has(id)) {
      shared += 1;
    }
  }

  const total = new Set([...first, ...second]).size;

  return Math.round((shared * 100) / total);
}

/** Gli interessi condivisi, nell'ordine di chi li guarda. */
function sharedInterests(viewer, author) {
  const second = new Set(interestsOf(author));

  return interestsOf(viewer).filter((id) => second.has(id));
}

/** Millisecondi dello scatto, con ripiego sull'istante corrente. */
function capturedAtMillis(daily, now) {
  const capturedAt = daily.capturedAt;

  if (capturedAt && typeof capturedAt.toMillis === 'function') {
    return capturedAt.toMillis();
  }

  return now.getTime();
}

/** Il documento da scrivere nel feed di chi guarda. */
function buildFeedEntry(daily, author, viewer, now) {
  return {
    dailyId: daily.id,
    authorId: author.id,
    authorName: author.name || '',
    authorAge: ageFrom(author.birthDate, now),
    // La foto profilo compare solo se verificata: quella in attesa non deve
    // sfuggire nel feed prima del controllo.
    authorPhotoUrl:
      author.photoStatus === 'active' ? author.photoUrl || '' : '',
    authorIcebreaker: author.icebreaker || '',
    authorInterests: interestsOf(author),
    // Affinita' e interessi in comune si calcolano qui perche' e' l'unico
    // punto che vede entrambi i profili: il client non puo' leggere quello
    // altrui, e da solo non saprebbe cosa confrontare.
    sharedInterests: sharedInterests(viewer, author),
    compatibility: compatibility(viewer, author),
    // L'etichetta del momento viaggia come identificativo: la scritta e
    // l'emoji le mette l'app, che e' l'unica a doverle mostrare.
    vibe: daily.vibe || '',
    photoUrl: daily.downloadUrl || '',
    dateKey: daily.dateKey || '',
    distanceKm: distanceKm(viewer, author),
    // Serve a ordinare le Daily di una stessa persona dentro la sua scheda.
    capturedAtMillis: capturedAtMillis(daily, now),
  };
}

module.exports = {
  MAX_DISTANCE_KM,
  covers,
  isCompatible,
  distanceKm,
  isEligible,
  canSee,
  ageFrom,
  buildFeedEntry,
  interestsOf,
  capturedAtMillis,
  compatibility,
  sharedInterests,
};
