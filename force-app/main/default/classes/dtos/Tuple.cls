public with sharing class Tuple {
  public Object item1 { get; private set; }
  public Object item2 { get; private set; }
  public Tuple(Object item1, Object item2) {
    this.item1 = item1;
    this.item2 = item2;
  }
}
