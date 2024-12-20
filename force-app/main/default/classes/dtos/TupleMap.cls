public with sharing class TupleMap {
  Map<Tuple, Object> objectByTuple = new Map<Tuple, Object>();

  public Set<Tuple> keySet() {
    return objectByTuple.keySet();
  }

  public Object get(Tuple key) {
    if (key == null) {
      return objectByTuple.get(key);
    }

    for (Tuple tup : objectByTuple.keySet()) {
      if (tup.item1 == key.item1 && tup.item2 == key.item2) {
        return objectByTuple.get(tup);
      }
    }
    return null;
  }

  public void put(Tuple tup, Object value) {
    for (Tuple tuple : objectByTuple.keySet()) {
      if (tuple.item1 == tup.item1 && tuple.item2 == tup.item2) {
        objectByTuple.put(tuple, value);
        return;
      }
    }
    objectByTuple.put(tup, value);
  }

  public Boolean containsKey(Tuple key) {
    if (key == null) {
      return objectByTuple.containsKey(key);
    }
    for (Tuple tuple : objectByTuple.keySet()) {
      if (tuple.item1 == key.item1 && tuple.item2 == key.item2) {
        return true;
      }
    }
    return false;
  }
}
