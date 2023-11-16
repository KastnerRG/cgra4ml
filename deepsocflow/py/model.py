from qkeras import Model

class QModel(Model):

    def __init(self, inputs, outputs, name=None):
        super().__init__(inputs, outputs, name=name)