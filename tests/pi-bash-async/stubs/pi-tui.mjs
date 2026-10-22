export class Text {
  constructor(text) {
    this.text = text;
  }
  render() {
    return [this.text];
  }
}
export const visibleWidth = (s) => s.length;
export const truncateToWidth = (s, w) => s.slice(0, w);
