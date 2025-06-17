export const FlowAttributeChangeEventName = 'lightning__flowattributechange';

export class FlowAttributeChangeEvent extends CustomEvent {
 constructor(attributeName, attributeValue) {
    super(FlowAttributeChangeEventName, {
        composed: true,
        cancelable: true,
        bubbles: true,
        detail: {
            attributeName,
            attributeValue
        }
    });
  }
}

export const FlowNavigationNextEventName = 'lightning__flownextevent';

export class FlowNavigationNextEvent extends CustomEvent {
 constructor(attributeName, attributeValue) {
    super(FlowNavigationNextEventName, {
        composed: true,
        cancelable: true,
        bubbles: true,
        detail: {
            attributeName,
            attributeValue
        }
    });
  }
}